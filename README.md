
Download the package index

```
curl -L  http://download.opensuse.org/tumbleweed/repo/oss/repodata/69cebf2bb8ca028a0096158754a020506fede251e0d0ff16c91979ea063eb5450ea1dbdc98cfc0a6b243f5aea603c9295ac75c64a9318b7ce5c9816f740db0a2-primary.xml.zst -o primary.xml.zst
curl -L http://download.opensuse.org/distribution/leap/16.0/repo/oss/repodata/8cc7dec90a1e9327f864b878739b64d4f793a59cb712e26ae32f25308e3023245bb3bf37082bde6d61002a6ece6644f5ea8883b9b8b5fcea996df01246f66692-primary.xml.zst -o leap-primary.xml.zst
```

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

Then created the switch like this

```
opam switch create opensuse --empty
opam repository add tumbleweed ~/opensuse/tumbleweed
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
zypper -n install opam
opam init -y --bare
opam switch create opensuse --empty
opam repository add tumbleweed --kind=local opensuse/tumbleweed
OPAMJOBS=1 opam install nano -y
```

# Fedora

https://fedora.mirrorservice.org/fedora/linux/releases/40/Everything/x86_64/os/repodata/

```
curl -L https://fedora.mirrorservice.org/fedora/linux/releases/39/Everything/x86_64/os/repodata/579f037cfd670a295af90427be9fe7acc3d2a03c2b6824fb286c1db75558ad64-other.xml.gz | gunzip > fedora39.xmlcurl -L https://fedora.mirrorservice.org/fedora/linux/releases/40/Everything/x86_64/os/repodata/b70b906963da8e73d3b09b98ea9a414a09f17d731324decb6138efc8f683b564-primary.xml.gz | gunzip > fedora40.xml
curl -L https://fedora.mirrorservice.org/fedora/linux/releases/39/Everything/x86_64/os/repodata/e681f4dcf1aa9814a1393a685d70b94210232b8997d2bc8a02c080e0ba8e51e3-primary.xml.gz | gunzip > fedora39.xml
```

Actual testing,

```
docker run -v ~/opensuse:/root/opensuse --rm -it fedora:latest
dnf -y install opam
opam init -y --bare
opam switch create fedora --empty
opam repository add fedora40 --kind=local opensuse/fedora40
OPAMJOBS=1 opam install nano -y
```

