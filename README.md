# Notes

RPM packages have a lists of things they provide and things which they require.

The application creates a mapping between the requirements and the provisions.
- Not all RPMs have satisifiable dependencies
- Some requirements are met by multiple providers
- Some packages are obsoleted by others.  e.g. requesting `antic` gives you `flint`

# Usage

Run this project with
```
dune exec -- opensuse {tumbleweed|leap|fedora40}
```

Test with Ryan's solver

```
git clone https://github.com/RyanGibb/opam-0install-solver
dune exec -- bin/main.exe --repo ~/opensuse/tumbleweed/packages nano
```

Created a file `~/opensuse/tumbleweed/repo` which contained

```
opam-version: "2.0"
```

Initially I ran into problems as there was a package called `opam` which caused `opam` to ignore the repository: `rm -r ~/opensuse/tumbleweed/packages/opam`

# Actual testing

Create a `Dockerfile`.  This use the Docker image created by the base
image builder to provide us with a precompiled `opam` executable.

```
FROM ocurrent/opam-staging:opensuse-tumbleweed-opam-amd64 AS build

FROM opensuse/tumbleweed:latest
COPY --from=build /usr/bin/opam-2.2 /usr/bin/opam
```

docker build . -tag opensuse/tumbleweed:opam

```
docker run -v ~/opensuse/tumbleweed:/root/tumbleweed --rm -it opensuse/tumbleweed:opam
opam init -k local --bare --bypass-checks -a -y /root/tumbleweed
opam switch create tumbleweed --empty
OPAMJOBS=1 opam install nano git vim -y
```

# Leap

```
docker run -v ~/opensuse/leap:/root/leap --rm -it opensuse/leap
bash -c "sh <(curl -fsSL https://raw.githubusercontent.com/ocaml/opam/master/shell/install.sh)"
opam init -k local --bare --bypass-checks -a -y /root/leap
opam switch create leap --empty
OPAMJOBS=1 opam install nano git vim -y
```

# Fedora


```
docker run -v ~/opensuse/fedora40:/root/fedora --rm -it fedora:latest
bash -c "sh <(curl -fsSL https://raw.githubusercontent.com/ocaml/opam/master/shell/install.sh)"
opam init -k local --bare --bypass-checks -a -y /root/fedora
opam switch create fedora --empty
OPAMJOBS=1 opam install nano git vim -y
```

