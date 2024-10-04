# rpm2opam

RPM packages have a lists of things they provide and things which they
require.  This application creates a mapping between the requirements
and the providers.

Not all RPMs have satisifiable dependencies which is then reflected
by opam.

Some requirements are met by multiple providers.  The alphabetically
first package is selected.

Some packages are obsoleted by others.  e.g. requesting `antic` may give
you `flint`

Many packages have circular dependencies.  A DFS search is performed on
all packages and any circular dependencies are removed. opam can't build
an installation graph when these exist.  Potentially the circular groups
could be merged into a single opam package and installed simultaneously
with `rpm -i *.rpm`.

opam's database is initally empty, but a Docker image contains installed
packages.  This can lead to conflicts particularly when A depends on B
and both are installed but opam tries to install a later version of B
but cannot as A blocks this.  Upgrading a Docker image with the local
tool circumvents that to an extent.

# Usage

Run this project with

```
dune exec --release -- rpm2opam {tumbleweed|leap|fedora|centos}
```

# Test with Ryan's solver

```
git clone https://github.com/RyanGibb/opam-0install-solver
dune exec -- bin/main.exe --repo ~/rpm2opam/tumbleweed/packages vim
```

# Test with Docker

```
docker run -v ~/rpm2opam/tumbleweed:/root/tumbleweed --rm -it opensuse/tumbleweed
zypper update -y  # ensure OS matches primary.xml
curl -L https://github.com/ocaml/opam/releases/download/2.2.1/opam-2.2.1-x86_64-linux -o /usr/bin/opam
chmod +x /usr/bin/opam
opam init -k local --bare --bypass-checks -a -y /root/tumbleweed
opam switch create tumbleweed --empty
OPAMJOBS=1 opam install vim -y
```

e.g.

```
f753afc1455e:/ # OPAMJOBS=1 opam install vim -y
[WARNING] Running as root is not recommended
The following actions will be performed:
=== install 28 packages
  - install alts                  1.2          [required by vim]
  - install bash                  5.2.37       [required by bash-sh]
  - install bash-sh               5.2.37       [required by vim]
  - install compat-usrmerge       84.87        [required by compat-usrmerge-tools]
  - install compat-usrmerge-tools 84.87        [required by filesystem]
  - install filesystem            84.87        [required by glibc]
  - install glibc                 2.40         [required by vim]
  - install libacl1               2.3.2        [required by vim]
  - install libalternatives1      1.2          [required by alts]
  - install libbz2-1              1.0.8        [required by perl]
  - install libcrypt1             4.4.36       [required by perl]
  - install libdb-4_8             4.8.30       [required by perl]
  - install libgcc_s1             14.2.0       [required by libdb-4_8]
  - install libgdbm6              1.24         [required by perl]
  - install libgdbm_compat4       1.24         [required by perl]
  - install libncurses6           6.5.20240928 [required by vim]
  - install libpcre2-8-0          10.44        [required by libselinux1]
  - install libreadline8          8.2.13       [required by bash]
  - install libselinux1           3.7          [required by vim]
  - install libstdc++6            14.2.0       [required by libdb-4_8]
  - install libz-ng-compat1       2.2.1        [required by perl]
  - install perl                  5.40.0       [required by vim]
  - install perl-base             5.40.0       [required by perl]
  - install system-user-root      20190513     [required by filesystem]
  - install terminfo-base         6.5.20240928 [required by libncurses6]
  - install vim                   9.1.718
  - install vim-data-common       9.1.718      [required by vim]
  - install xxd                   9.1.718      [required by vim]

<><> Processing actions <><><><><><><><><><><><><><><><><><><><><><><><><><><><>
-> retrieved bash-sh.5.2.37  (http://download.opensuse.org/tumbleweed/repo/oss/noarch/bash-sh-5.2.37-14.1.noarch.rpm)
-> retrieved alts.1.2  (http://download.opensuse.org/tumbleweed/repo/oss/x86_64/alts-1.2+30.a5431e9-1.5.x86_64.rpm)
-> retrieved compat-usrmerge.84.87  (http://download.opensuse.org/tumbleweed/repo/oss/x86_64/compat-usrmerge-84.87-5.20.x86_64.rpm)
-> retrieved bash.5.2.37  (http://download.opensuse.org/tumbleweed/repo/oss/x86_64/bash-5.2.37-14.1.x86_64.rpm)
-> retrieved compat-usrmerge-tools.84.87  (http://download.opensuse.org/tumbleweed/repo/oss/x86_64/compat-usrmerge-tools-84.87-5.20.x86_64.rpm)
-> retrieved filesystem.84.87  (http://download.opensuse.org/tumbleweed/repo/oss/x86_64/filesystem-84.87-15.3.x86_64.rpm)
-> retrieved libacl1.2.3.2  (http://download.opensuse.org/tumbleweed/repo/oss/x86_64/libacl1-2.3.2-2.1.x86_64.rpm)
-> retrieved libalternatives1.1.2  (http://download.opensuse.org/tumbleweed/repo/oss/x86_64/libalternatives1-1.2+30.a5431e9-1.5.x86_64.rpm)
-> retrieved glibc.2.40  (http://download.opensuse.org/tumbleweed/repo/oss/x86_64/glibc-2.40-2.1.x86_64.rpm)
-> retrieved libbz2-1.1.0.8  (http://download.opensuse.org/tumbleweed/repo/oss/x86_64/libbz2-1-1.0.8-5.10.x86_64.rpm)
-> retrieved libcrypt1.4.4.36  (http://download.opensuse.org/tumbleweed/repo/oss/x86_64/libcrypt1-4.4.36-1.6.x86_64.rpm)
-> retrieved libdb-4_8.4.8.30  (http://download.opensuse.org/tumbleweed/repo/oss/x86_64/libdb-4_8-4.8.30-45.1.x86_64.rpm)
-> retrieved libgcc_s1.14.2.0  (http://download.opensuse.org/tumbleweed/repo/oss/x86_64/libgcc_s1-14.2.0+git10526-2.1.x86_64.rpm)
-> retrieved libgdbm6.1.24  (http://download.opensuse.org/tumbleweed/repo/oss/x86_64/libgdbm6-1.24-1.1.x86_64.rpm)
-> retrieved libgdbm_compat4.1.24  (http://download.opensuse.org/tumbleweed/repo/oss/x86_64/libgdbm_compat4-1.24-1.1.x86_64.rpm)
-> retrieved libncurses6.6.5.20240928  (http://download.opensuse.org/tumbleweed/repo/oss/x86_64/libncurses6-6.5.20240928-46.1.x86_64.rpm)
-> retrieved libreadline8.8.2.13  (http://download.opensuse.org/tumbleweed/repo/oss/x86_64/libreadline8-8.2.13-2.1.x86_64.rpm)
-> retrieved libselinux1.3.7  (http://download.opensuse.org/tumbleweed/repo/oss/x86_64/libselinux1-3.7-1.1.x86_64.rpm)
-> retrieved libpcre2-8-0.10.44  (http://download.opensuse.org/tumbleweed/repo/oss/x86_64/libpcre2-8-0-10.44-1.1.x86_64.rpm)
-> retrieved libz-ng-compat1.2.2.1  (http://download.opensuse.org/tumbleweed/repo/oss/x86_64/libz-ng-compat1-2.2.1-1.1.x86_64.rpm)
-> retrieved libstdc++6.14.2.0  (http://download.opensuse.org/tumbleweed/repo/oss/x86_64/libstdc++6-14.2.0+git10526-2.1.x86_64.rpm)
-> retrieved system-user-root.20190513  (http://download.opensuse.org/tumbleweed/repo/oss/noarch/system-user-root-20190513-2.16.noarch.rpm)
-> retrieved perl.5.40.0  (http://download.opensuse.org/tumbleweed/repo/oss/x86_64/perl-5.40.0-2.1.x86_64.rpm)
-> retrieved terminfo-base.6.5.20240928  (http://download.opensuse.org/tumbleweed/repo/oss/x86_64/terminfo-base-6.5.20240928-46.1.x86_64.rpm)
-> retrieved perl-base.5.40.0  (http://download.opensuse.org/tumbleweed/repo/oss/x86_64/perl-base-5.40.0-2.1.x86_64.rpm)
-> installed compat-usrmerge.84.87
-> retrieved vim-data-common.9.1.718  (http://download.opensuse.org/tumbleweed/repo/oss/noarch/vim-data-common-9.1.0718-1.1.noarch.rpm)
-> retrieved vim.9.1.718  (http://download.opensuse.org/tumbleweed/repo/oss/x86_64/vim-9.1.0718-1.1.x86_64.rpm)
-> retrieved xxd.9.1.718  (http://download.opensuse.org/tumbleweed/repo/oss/x86_64/xxd-9.1.0718-1.1.x86_64.rpm)
-> installed system-user-root.20190513
-> installed compat-usrmerge-tools.84.87
-> installed terminfo-base.6.5.20240928
-> installed filesystem.84.87
-> installed vim-data-common.9.1.718
-> installed glibc.2.40
-> installed libacl1.2.3.2
-> installed libalternatives1.1.2
-> installed libbz2-1.1.0.8
-> installed alts.1.2
-> installed libcrypt1.4.4.36
-> installed libgcc_s1.14.2.0
-> installed libgdbm6.1.24
-> installed libpcre2-8-0.10.44
-> installed libgdbm_compat4.1.24
-> installed libselinux1.3.7
-> installed libstdc++6.14.2.0
-> installed libz-ng-compat1.2.2.1
-> installed libdb-4_8.4.8.30
-> installed libncurses6.6.5.20240928
-> installed perl-base.5.40.0
-> installed libreadline8.8.2.13
-> installed perl.5.40.0
-> installed bash.5.2.37
-> installed xxd.9.1.718
-> installed bash-sh.5.2.37
-> installed vim.9.1.718
Done.
# Run eval $(opam env) to update the current shell environment
```

