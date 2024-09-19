
Download the package index

```
curl -L  http://download.opensuse.org/tumbleweed/repo/oss/repodata/69cebf2bb8ca028a0096158754a020506fede251e0d0ff16c91979ea063eb5450ea1dbdc98cfc0a6b243f5aea603c9295ac75c64a9318b7ce5c9816f740db0a2-primary.xml.zst -o primary.xml.zst
```

Test with Ryan's solver

```
git clone https://github.com/RyanGibb/opam-0install-solver
dune exec -- bin/main.exe --repo ~/opensuse/packages nano
```

Created a file `~/opensuse/repo` which contained

```
opam-version: "2.0"
```

Then created the switch like this

```
opam switch create opensuse --empty
opam repository add tumbleweed ~/opensuse
```

Initially I ran into problems as there was a package called opam which caused opam to ignore the repository.

```
$ opam install nano
The following actions will be performed:
=== install 15 packages
  ∗ compat-usrmerge-tools 84.87        [required by filesystem]
  ∗ file-magic            5.45         [required by libmagic1]
  ∗ filesystem            84.87        [required by glibc]
  ∗ glibc                 2.40         [required by nano]
  ∗ libbz2-1              1.0.8        [required by libmagic1]
  ∗ libgcc_s1             14.2.0       [required by libncurses6]
  ∗ liblzma5              5.6.2        [required by libmagic1]
  ∗ libmagic1             5.45         [required by nano]
  ∗ libncurses6           6.5.20240824 [required by nano]
  ∗ libstdc++6            14.2.0       [required by libncurses6]
  ∗ libz-ng-compat1       2.2.1        [required by libmagic1]
  ∗ libzstd1              1.5.6        [required by libmagic1]
  ∗ nano                  8.1
  ∗ system-user-root      20190513     [required by filesystem]
  ∗ terminfo-base         6.5.20240824 [required by libncurses6]

Proceed with ∗ 15 installations? [y/n] y
```

Actual testing,

```
docker run -v ~/opensuse:/root/opensuse --rm -it opensuse/tumbleweed
zypper install opam
opam init -y --bare
opam switch create opensuse --empty
opam repository add tumbleweed ~/opensuse

