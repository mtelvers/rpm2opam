let primary = Xml.parse_file "primary.xml"

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
}

type rpm = {
  pkg : string;
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

let string_of_entry e =
  match (e.flags, e.ver) with
  | Some flags, Some ver -> "\"" ^ e.name ^ "\" {" ^ symbol_of_flag flags ^ " \"" ^ string_of_version ver ^ "\"}"
  | _, _ -> "\"" ^ e.name ^ "\""

let rpms =
  Xml.map
    (fun package ->
      Xml.fold
        (fun acc xml ->
          match Xml.tag xml with
          | "name" -> { acc with pkg = Xml.children xml |> List.hd |> Xml.pcdata }
          | "version" -> { acc with version = Xml.attrib xml "ver" |> version_of_string }
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
                    | _ -> acc)
                  { requires = []; provides = [] } xml
              in
              { acc with details }
          | _ -> acc)
        { pkg = ""; version = []; location = ""; details = { provides = []; requires = [] } }
        package)
    primary

let mkdir_p s =
  String.split_on_char '/' s
  |> List.fold_left
       (fun acc d ->
         let p = if String.length acc > 0 then acc ^ "/" ^ d else d in
         let () = if not (Sys.file_exists p) then Sys.mkdir p 0o755 in
         p)
       ""

let () =
  List.iter
    (fun rpm ->
      let dir = "packages/" ^ rpm.pkg ^ "/" ^ rpm.pkg ^ "." ^ string_of_version rpm.version in
      let _ = mkdir_p dir in
      let oc = open_out (dir ^ "/opam") in
      let () = Printf.fprintf oc "opam-version: \"2.0\"\n" in
      let () = Printf.fprintf oc "build: [\n" in
      let rpm_filename = String.split_on_char '/' rpm.location |> List.rev |> List.hd in
      let () = Printf.fprintf oc "  [\"zypper -n install %s\"]\n" rpm_filename in
      let () = Printf.fprintf oc "]\n" in
      let () = Printf.fprintf oc "remove: [\n" in
      let () = Printf.fprintf oc "  [\"zypper -n remove %s\"]\n" rpm.pkg in
      let () = Printf.fprintf oc "]\n" in
      let () = Printf.fprintf oc "depends: [\n" in
      let pkgs =
        List.fold_left
          (fun acc r ->
            let () = Printf.printf "requires %s\n" r.name in
            let best =
              List.fold_left
                (fun acc rpm ->
                  List.fold_left
                    (fun acc p ->
                      match (r.flags, r.ver) with
                      | None, _ -> if r.name = p.name then { name = rpm.pkg; flags = None; ver = Some rpm.version } :: acc else acc
                      | Some "GT", Some version ->
                          if r.name = p.name && compare version rpm.version > 0 then { name = rpm.pkg; flags = Some "GT"; ver = Some rpm.version } :: acc
                          else acc
                      | Some "GE", Some version ->
                          if r.name = p.name && compare version rpm.version >= 0 then { name = rpm.pkg; flags = Some "GE"; ver = Some rpm.version } :: acc
                          else acc
                      | Some "LT", Some version ->
                          if r.name = p.name && compare version rpm.version < 0 then { name = rpm.pkg; flags = Some "LT"; ver = Some rpm.version } :: acc
                          else acc
                      | Some "LE", Some version ->
                          if r.name = p.name && compare version rpm.version <= 0 then { name = rpm.pkg; flags = Some "LE"; ver = Some rpm.version } :: acc
                          else acc
                      | Some "EQ", Some version ->
                          if r.name = p.name && compare version rpm.version = 0 then { name = rpm.pkg; flags = Some "EQ"; ver = Some rpm.version } :: acc
                          else acc)
                    acc rpm.details.provides)
                [] rpms
              |> List.sort (fun a b -> compare a.ver b.ver)
              |> List.rev
            in
            let () = List.iter (fun r -> Printf.printf "-- %s (%s)\n" r.name (Option.value ~default:[ 0 ] r.ver |> string_of_version)) best in
            match best with
            | [] -> acc
            | hd :: _ ->
                let () = Printf.printf "keeping %s\n" hd.name in
                hd :: acc)
          [] rpm.details.requires
        |> List.sort_uniq compare
      in
      let () = List.iter (fun p -> Printf.fprintf oc "  %s\n" (string_of_entry p)) pkgs in
      let () = Printf.fprintf oc "]\n" in
      let () = Printf.fprintf oc "extra-source \"%s\" {\n" rpm_filename in
      let () = Printf.fprintf oc "  src: \"http://download.opensuse.org/tumbleweed/repo/oss/%s\"\n" rpm.location in
      let () = Printf.fprintf oc "}\n" in
      close_out oc)
    rpms
