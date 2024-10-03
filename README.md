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

```
docker run -v ~/opensuse/tumbleweed:/root/tumbleweed --rm -it opensuse/tumbleweed
curl -L https://github.com/ocaml/opam/releases/download/2.2.1/opam-2.2.1-x86_64-linux -o /usr/bin/opam
chmod +x /usr/bin/opam
opam init -k local --bare --bypass-checks -a -y /root/tumbleweed
opam switch create tumbleweed --empty
OPAMJOBS=1 opam install nano git vim -y
```

rpm -qa --qf "%{NAME} %{VERSION}\n" | sort | {
echo 'opam-version: "2.0"' > ~/.opam/tumbleweed/.opam-switch/switch-state
echo 'installed: [' >> ~/.opam/tumbleweed/.opam-switch/switch-state
mkdir -p ~/.opam/tumbleweed/.opam-switch/install
while read -r pkg ver ; do
  ver="${ver%%+*}"
  ver="${ver%%~*}"
  ver="${ver%%-*}"
  echo installing $pkg $ver
  ls ~/.opam/repo/default/packages/$pkg/$pkg.$ver/opam
  if [ -f ~/.opam/repo/default/packages/$pkg/$pkg.$ver/opam ] ; then
    mkdir -p ~/.opam/tumbleweed/.opam-switch/packages/$pkg.$ver
    cp ~/.opam/repo/default/packages/$pkg/$pkg.$ver/opam ~/.opam/tumbleweed/.opam-switch/packages/$pkg.$ver/opam
    cp ~/.opam/repo/default/packages/$pkg/$pkg.$ver/opam ~/.opam/tumbleweed/.opam-switch/install/$pkg.changes
    echo '"'$pkg.$ver'"' >> ~/.opam/tumbleweed/.opam-switch/switch-state
    else
    echo skipped
  fi
  done
  echo ']' >> ~/.opam/tumbleweed/.opam-switch/switch-state
}

e.g.

mkdir ~/.opam/tumbleweed/.opam-switch/packages/glibc-locale-base.2.40
cp ~/tumbleweed/packages/glibc-locale-base/glibc-locale-base.2.40/opam ~/.opam/tumbleweed/.opam-switch/packages/glibc-locale-base.2.40/opam
echo 'opam-version: "2.0"' > .opam-switch/install/glibc-locale-base.changes

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

