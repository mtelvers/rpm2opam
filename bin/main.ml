type distribution = {
  name : string;
  prefix : string;
  url : string;
}

let distributions =
  [
    ("tumbleweed", { name = "tumbleweed"; prefix = ""; url = "http://download.opensuse.org/tumbleweed/repo/oss" });
    ("leap", { name = "leap"; prefix = ""; url = "http://download.opensuse.org/distribution/leap/16.0/repo/oss" });
    ("fedora", { name = "fedora"; prefix = ""; url = "https://fedora.mirrorservice.org/fedora/linux/releases/40/Everything/x86_64/os" });
    ("centos", { name = "centos"; prefix = ""; url = "https://mirror.stream.centos.org/10-stream/BaseOS/x86_64/os" });
  ]

let distribution =
  try List.assoc Sys.argv.(1) distributions with
  | _ -> assert false

let _ = Sys.command ("curl " ^ distribution.url ^ "/repodata/repomd.xml -o repomd.xml")
let repo = Xml.parse_file "repomd.xml"

let primary_url =
  Xml.map
    (fun xml ->
      match Xml.tag xml with
      | "data" ->
          let ty = Xml.attrib xml "type" in
          Some
            (Xml.fold
               (fun acc xml ->
                 match Xml.tag xml with
                 | "location" ->
                     let href = Xml.attrib xml "href" in
                     (ty, href)
                 | _ -> acc)
               ("", "") xml)
      | _ -> None)
    repo
  |> List.filter_map (fun x -> x)
  |> List.assoc "primary"

let primary_filename = String.split_on_char '/' primary_url |> List.rev |> List.hd
let primary_xml = Filename.remove_extension primary_filename

let _ =
  if not (Sys.file_exists primary_xml) then
    let _ = Sys.command ("curl -L " ^ distribution.url ^ "/" ^ primary_url ^ " -o " ^ primary_filename) in
    match Filename.extension primary_filename with
    | ".gz" -> Sys.command ("gunzip " ^ primary_filename)
    | ".zst" -> Sys.command ("unzstd " ^ primary_filename)
    | _ -> 0
  else 0

let primary = Xml.parse_file primary_xml

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

type flag =
  [ `EQ
  | `GE
  | `GT
  | `LT
  | `LE
  ]

let flag_of_string = function
  | "EQ" -> `EQ
  | "GE" -> `GE
  | "GT" -> `GT
  | "LT" -> `LT
  | "LE" -> `LE
  | _ -> assert false

let symbol_of_flag = function
  | `EQ -> "="
  | `GE -> ">="
  | `GT -> ">"
  | `LT -> "<"
  | `LE -> "<="
  | _ -> assert false

type con = {
  flags : flag;
  ver : int list;
}

let string_of_constraint = function
  | Some c -> "{" ^ symbol_of_flag c.flags ^ " \"" ^ string_of_version c.ver ^ "\"}"
  | _ -> ""

type entry = {
  name : string;
  con : con option;
}

type details = {
  requires : entry list;
  provides : entry list;
  conflicts : entry list;
  files : string list;
}

type rpm = {
  pkg : string;
  arch : string;
  version : int list;
  location : string;
  details : details;
}

let dots_to_dashes s = String.split_on_char '.' s |> String.concat "-"

let remove_brackets s =
  let len = String.length s in
  String.sub s 1 (len - 2)

let list_of_xml_entry =
  Xml.map (fun xml ->
      let a = Xml.attribs xml in
      let name = List.assoc "name" a in
      let name =
        if String.get name 0 = '(' then
          let words = remove_brackets name |> String.split_on_char ' ' in
          List.nth words 0
        else name
      in
      let con =
        match List.assoc_opt "flags" a with
        | Some flags -> Some { flags = flag_of_string flags; ver = List.assoc "ver" a |> version_of_string }
        | None -> None
      in
      { name; con })

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
                    | "rpm:requires" -> { acc with requires = list_of_xml_entry xml }
                    | "rpm:provides" -> { acc with provides = list_of_xml_entry xml }
                    | "rpm:conflicts" -> { acc with conflicts = list_of_xml_entry xml }
                    | "file" -> { acc with files = (Xml.children xml |> List.hd |> Xml.pcdata) :: acc.files }
                    | _ -> acc)
                  { requires = []; provides = []; conflicts = []; files = [] }
                  xml
              in
              { acc with details }
          | _ -> acc)
        { pkg = ""; arch = ""; version = []; location = ""; details = { provides = []; requires = []; conflicts = []; files = [] } }
        package)
    primary

let rpms = List.filter (fun rpm -> rpm.arch = "x86_64" || rpm.arch = "noarch") rpms
let provides = Hashtbl.create 100000
let () = List.iter (fun rpm -> List.iter (fun p -> Hashtbl.add provides p.name (p, rpm)) rpm.details.provides) rpms

let search req =
  let matches =
    Hashtbl.find_all provides req.name
    |> List.filter_map (fun (pro, rpm) ->
           match (req.con, pro.con) with
           | None, _
           | _, None ->
               Some (req, rpm)
           | Some reqc, Some proc -> (
               match reqc.flags with
               | `EQ -> if compare proc.ver reqc.ver = 0 then Some (req, rpm) else None
               | `GE -> if compare proc.ver reqc.ver >= 0 then Some (req, rpm) else None
               | `GT -> if compare proc.ver reqc.ver > 0 then Some (req, rpm) else None
               | `LE -> if compare proc.ver reqc.ver <= 0 then Some (req, rpm) else None
               | `LT -> if compare proc.ver reqc.ver < 0 then Some (req, rpm) else None))
  in
  if List.length matches = 0 then
    List.filter
      (fun rpm ->
        let m = List.filter (fun file -> req.name = file) rpm.details.files in
        List.length m > 0)
      rpms
    |> List.map (fun rpm -> ({ name = req.name; con = None }, rpm))
  else matches

let db = Hashtbl.create 100000

let () =
  List.iter
    (fun rpm ->
      let packages =
        rpm.details.requires |> List.map search
        |> List.filter_map (fun l ->
               let l = List.sort (fun (_, rpm1) (_, rpm2) -> compare rpm1.pkg rpm2.pkg) l in
               if List.length l > 0 then Some (List.hd l) else None)
        |> List.map (fun (e, r) -> { name = r.pkg; con = e.con })
        |> List.sort_uniq (fun r1 r2 -> compare r1.name r2.name)
      in
      Hashtbl.add db rpm.pkg packages)
    rpms

let visited = Hashtbl.create 100000

let rec dfs bt r =
  let deps = Hashtbl.find db r in
  List.iter
    (fun d ->
      if List.mem d.name bt then Hashtbl.replace db r (List.filter (fun e -> e.name <> d.name) deps)
      else
        match Hashtbl.find_opt visited d.name with
        | Some _ -> ()
        | None ->
            let () = dfs (r :: bt) d.name in
            Hashtbl.add visited d.name true)
    deps

let () =
  List.iter
    (fun r ->
      let () = Printf.printf "%s\n" r.pkg in
      let () = dfs [] r.pkg in
      flush stdout)
    rpms

let mkdir_p s =
  String.split_on_char '/' s
  |> List.fold_left
       (fun acc d ->
         let p = if String.length acc > 0 then acc ^ "/" ^ d else d in
         let () = if not (Sys.file_exists p) then Sys.mkdir p 0o755 in
         p)
       ""

let quoted_string lst = List.map (fun x -> "\"" ^ x ^ "\"") lst |> String.concat " "

(* opam can't handle a package called "opam" *)
let rpms = List.filter (fun rpm -> rpm.pkg <> "opam") rpms

let () =
  let _ = mkdir_p distribution.name in
  let oc = open_out (distribution.name ^ "/repo") in
  let () = Printf.fprintf oc "opam-version: \"2.0\"\n" in
  close_out oc

let () =
  List.iter
    (fun rpm ->
      let () = Printf.printf "Package: %s\n" rpm.pkg in
      let dir = distribution.name ^ "/packages/" ^ distribution.prefix ^ rpm.pkg ^ "/" ^ distribution.prefix ^ rpm.pkg ^ "." ^ string_of_version rpm.version in
      let _ = mkdir_p dir in
      let oc = open_out (dir ^ "/opam") in
      let () = Printf.fprintf oc "opam-version: \"2.0\"\n" in
      let rpm_filename = String.split_on_char '/' rpm.location |> List.rev |> List.hd in
      let () = Printf.fprintf oc "build: [%s]\n" ([ "/usr/bin/rpm"; "-U"; "--replacepkgs"; rpm_filename ] |> quoted_string) in
      let () = Printf.fprintf oc "remove: [%s]\n" ([ "/usr/bin/rpm"; "-e"; rpm_filename ] |> quoted_string) in
      let () = Printf.fprintf oc "depends: [\n" in
      let () = List.iter (fun e -> Printf.fprintf oc "  \"%s%s\" %s\n" distribution.prefix e.name (string_of_constraint e.con)) (Hashtbl.find db rpm.pkg) in
      let () = Printf.fprintf oc "]\n" in
      let () = Printf.fprintf oc "extra-source \"%s\" {\n" rpm_filename in
      let () = Printf.fprintf oc "  src: \"%s/%s\"\n" distribution.url rpm.location in
      let () = Printf.fprintf oc "}\n" in
      close_out oc)
    rpms
