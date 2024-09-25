type distribution = {
  name : string;
  prefix : string;
  url : string;
  file : string;
  build : string list;
  remove : string list;
}

let distributions =
  [
    ( "tumbleweed",
      {
        name = "tumbleweed";
        prefix = "";
        url = "http://download.opensuse.org/tumbleweed/repo/oss";
        file = "tumbleweed-primary.xml";
        build = [ "/usr/bin/zypper"; "n"; "install" ];
        remove = [ "/usr/bin/zypper"; "-n"; "remove" ];
      } );
    ( "leap",
      {
        name = "leap";
        prefix = "";
        url = "http://download.opensuse.org/distribution/leap/16.0/repo/oss";
        file = "leap-primary.xml";
        build = [ "/usr/bin/zypper"; "-n"; "install" ];
        remove = [ "/usr/bin/zypper"; "-n"; "remove" ];
      } );
    ( "fedora40",
      {
        name = "fedora40";
        prefix = "";
        url = "https://fedora.mirrorservice.org/fedora/linux/releases/40/Everything/x86_64/os";
        file = "fedora40.xml";
        build = [ "/usr/bin/dnf"; "-y"; "install" ];
        remove = [ "/usr/bin/dnf"; "-y"; "remove" ];
      } );
  ]

let distribution =
  try List.assoc Sys.argv.(1) distributions with
  | _ -> assert false

let primary = Xml.parse_file distribution.file

let version_of_string s =
  let rec loop i r = function
    | [] -> i :: r
    | hd :: tl -> (
        match hd with
        | '0' -> loop (i * 10) r tl
        | '1' -> loop ((i * 10) + 1) r tl
        | '2' -> loop ((i * 10) + 2) r tl
        | '3' -> loop ((i * 10) + 3) r tl
        | '4' -> loop ((i * 10) + 4) r tl
        | '5' -> loop ((i * 10) + 5) r tl
        | '6' -> loop ((i * 10) + 6) r tl
        | '7' -> loop ((i * 10) + 7) r tl
        | '8' -> loop ((i * 10) + 8) r tl
        | '9' -> loop ((i * 10) + 9) r tl
        | '.' -> loop 0 (i :: r) tl
        | _ -> i :: r)
  in
  List.init (String.length s) (String.get s) |> loop 0 [] |> List.rev

let string_of_version v = List.map string_of_int v |> String.concat "."

type entry = {
  name : string;
  flags : string option;
  ver : int list option;
}

type details = {
  requires : entry list;
  provides : entry list;
  conflicts : entry list;
}

type rpm = {
  pkg : string;
  arch : string;
  version : int list;
  location : string;
  details : details;
}

let symbol_of_flag = function
  | "EQ" -> "="
  | "GE" -> ">="
  | "GT" -> ">"
  | "LT" -> "<"
  | "LE" -> "<="
  | _ -> assert false

let string_of_constraints e =
  match (e.flags, e.ver) with
  | Some flags, Some ver -> "{" ^ symbol_of_flag flags ^ " \"" ^ string_of_version ver ^ "\"}"
  | _, _ -> ""

let dots_to_dashes s = String.split_on_char '.' s |> String.concat "-"

let rpms =
  Xml.map
    (fun package ->
      Xml.fold
        (fun acc xml ->
          match Xml.tag xml with
          | "name" -> { acc with pkg = Xml.children xml |> List.hd |> Xml.pcdata |> dots_to_dashes }
          | "version" -> { acc with version = Xml.attrib xml "ver" |> version_of_string }
          | "arch" -> { acc with arch = Xml.children xml |> List.hd |> Xml.pcdata }
          | "location" -> { acc with location = Xml.attrib xml "href" }
          | "format" ->
              let details =
                Xml.fold
                  (fun acc xml ->
                    match Xml.tag xml with
                    | "rpm:requires" ->
                        let lst =
                          Xml.map
                            (fun xml ->
                              let a = Xml.attribs xml in
                              { name = List.assoc "name" a; flags = List.assoc_opt "flags" a; ver = List.assoc_opt "ver" a |> Option.map version_of_string })
                            xml
                        in
                        { acc with requires = lst }
                    | "rpm:provides" ->
                        let lst =
                          Xml.map
                            (fun xml ->
                              let a = Xml.attribs xml in
                              { name = List.assoc "name" a; flags = List.assoc_opt "flags" a; ver = List.assoc_opt "ver" a |> Option.map version_of_string })
                            xml
                        in
                        { acc with provides = lst }
                    | "rpm:conflicts" ->
                        let lst =
                          Xml.map
                            (fun xml ->
                              let a = Xml.attribs xml in
                              { name = List.assoc "name" a; flags = List.assoc_opt "flags" a; ver = List.assoc_opt "ver" a |> Option.map version_of_string })
                            xml
                        in
                        { acc with conflicts = lst }
                    | _ -> acc)
                  { requires = []; provides = []; conflicts = [] } xml
              in
              { acc with details }
          | _ -> acc)
        { pkg = ""; arch = ""; version = []; location = ""; details = { provides = []; requires = []; conflicts = [] } }
        package)
    primary

let rpms = List.filter (fun rpm -> rpm.arch = "x86_64") rpms
let provides = Hashtbl.create 100000
let () = List.iter (fun rpm -> List.iter (fun p -> Hashtbl.add provides p.name (p, rpm)) rpm.details.provides) rpms

let tests =
  [
    { name = "/bin/sh"; flags = Some "EQ"; ver = Some [ 5; 9 ] };
    { name = "libxml2.so.2()(64bit)"; flags = None; ver = None };
    { name = "libxml2.so.2(LIBXML2_2.4.30)(64bit)"; flags = None; ver = None };
    { name = "libgcc_s.so.1()(64bit)"; flags = None; ver = None };
    { name = "python3"; flags = Some "GE"; ver = Some [ 3; 6 ] };
  ]

let search req =
  Hashtbl.find_all provides req.name
  |> List.filter_map (fun (pro, rpm) ->
         match (req.flags, req.ver, pro.ver) with
         | None, _, _
         | Some _, _, None ->
             Some (req, rpm)
         | Some "EQ", Some reqver, Some prover -> if compare prover reqver = 0 then Some (req, rpm) else None
         | Some "GE", Some reqver, Some prover -> if compare prover reqver >= 0 then Some (req, rpm) else None
         | Some "GT", Some reqver, Some prover -> if compare prover reqver > 0 then Some (req, rpm) else None
         | Some "LE", Some reqver, Some prover -> if compare prover reqver <= 0 then Some (req, rpm) else None
         | Some "LT", Some reqver, Some prover -> if compare prover reqver < 0 then Some (req, rpm) else None
         | Some v, _, _ ->
             print_endline v;
             assert false)

let latest_rpm r =
  if List.length r > 0 then
    Some
      (List.sort
         (fun (_, p1) (_, p2) ->
           let c = -compare p1.version p2.version in
           if c <> 0 then c else compare p1.pkg p2.pkg)
         r
      |> List.hd)
  else None

let filter_entries = List.filter (fun e -> String.get e.name 0 <> '/')
let () = List.map search tests |> List.flatten |> List.iter (fun (req, rpm) -> Printf.printf "%s @ %s\n" rpm.pkg (string_of_constraints req))
let r = List.filter_map (fun req -> search req |> latest_rpm) tests |> List.sort_uniq compare
let () = List.iter (fun (req, rpm) -> Printf.printf "%s @ %s\n" rpm.pkg (string_of_constraints req)) r

let mkdir_p s =
  String.split_on_char '/' s
  |> List.fold_left
       (fun acc d ->
         let p = if String.length acc > 0 then acc ^ "/" ^ d else d in
         let () = if not (Sys.file_exists p) then Sys.mkdir p 0o755 in
         p)
       ""

let quoted_string lst = List.map (fun x -> "\"" ^ x ^ "\"") lst |> String.concat " "

let () =
  List.iter
    (fun rpm ->
      let () = Printf.printf "Package: %s\n" rpm.pkg in
      let dir = distribution.name ^ "/packages/" ^ distribution.prefix ^ rpm.pkg ^ "/" ^ distribution.prefix ^ rpm.pkg ^ "." ^ string_of_version rpm.version in
      let _ = mkdir_p dir in
      let oc = open_out (dir ^ "/opam") in
      let () = Printf.fprintf oc "opam-version: \"2.0\"\n" in
      let () = Printf.fprintf oc "build: [\n" in
      let rpm_filename = String.split_on_char '/' rpm.location |> List.rev |> List.hd in
      let () = Printf.fprintf oc "  [%s]\n" (distribution.build @ [ rpm_filename ] |> quoted_string) in
      let () = Printf.fprintf oc "]\n" in
      let () = Printf.fprintf oc "remove: [\n" in
      let () = Printf.fprintf oc "  [%s]\n" (distribution.remove @ [ rpm_filename ] |> quoted_string) in
      let () = Printf.fprintf oc "]\n" in
      let () = Printf.fprintf oc "depends: [\n" in
      let pkgs =
        filter_entries rpm.details.requires
        |> List.filter_map (fun e -> search e |> latest_rpm)
        |> List.sort_uniq (fun (_, rpm1) (_, rpm2) -> compare rpm1.pkg rpm2.pkg)
      in
      let () =
        List.iter
          (fun (req, p) ->
            Printf.fprintf oc "  \"%s%s\" %s\n" distribution.prefix p.pkg (string_of_constraints { name = ""; flags = req.flags; ver = Some p.version }))
          pkgs
      in
      let () = Printf.fprintf oc "]\n" in
      (*
      let () =
        if List.length rpm.details.conflicts > 0 then
          let () = Printf.fprintf oc "conflicts: [\n" in
          let () = List.iter (fun con -> Printf.fprintf oc "  \"%s%s\" %s\n" distribution.prefix con.name (string_of_constraints con)) rpm.details.conflicts in
          Printf.fprintf oc "]\n"
      in
         *)
      let () = Printf.fprintf oc "extra-source \"%s\" {\n" rpm_filename in
      let () = Printf.fprintf oc "  src: \"%s/%s\"\n" distribution.url rpm.location in
      let () = Printf.fprintf oc "}\n" in
      close_out oc)
    rpms
