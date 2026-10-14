{
  linkFarm,
  fetchzip,
  fetchgit,
}:
linkFarm "zig-packages" [
  {
    name = "capstone-6.0.0-Alpha11-tmNUgchCAADseBl0X3r-1OeBGnnCh81Mzef9IVsyDBZ6";
    path = fetchgit {
      url = "https://github.com/allyourcodebase/capstone";
      rev = "3769b1ec041b7c38813b9f7780946dc4dda3723e";
      hash = "sha256-ftxBMwyCc0GI7xTeUMN/r1zJMSKWAkTglW1QoZBI8Wo=";
    };
  }
  {
    name = "N-V-__8AAGSR-wXE6Il6wd99ZTYMdfedaJwwFv_BJX9E4TqP";
    path = fetchzip {
      url = "https://github.com/capstone-engine/capstone/archive/refs/tags/6.0.0-Alpha11.tar.gz";
      hash = "sha256-ShiRgCDhzJB3/t/jeiWWa1IQgj254S7/8MGXjD+TUiM=";
    };
  }
  {
    name = "nativefiledialog_extended-1.3.0-dev-_pDry8IdAAAWgvctTyivfRJ99NgTXUTw3YQL9h9gosOS";
    path = fetchgit {
      url = "https://github.com/allyourcodebase/nativefiledialog-extended";
      rev = "3ac41848ceec6b08fd6cd8ae5338a6ac854ec327";
      hash = "sha256-eKzGFyBSMmE1rAdW9HkOQpduHvIDW7Zz/uwGbMZsJfo=";
    };
  }
  {
    name = "N-V-__8AAEVlCwBOSCaKkar7E3a_r5eFFLvXlhcKFEDKi-YX";
    path = fetchgit {
      url = "https://github.com/btzy/nativefiledialog-extended";
      rev = "7bbbd9fe6b1d1549b41df138f614d1a44df9ba08";
      hash = "sha256-kOosw/UY0B6O+DQUesDijtIn7rOWdRaVtiFU0DuPVqU=";
    };
  }

  # C/C++ dependencies without a Zig build script

  {
    name = "N-V-__8AALwkAAB_H_lRcdLYz-_DCoAy71ze0CtKLsHdDRD-";
    path = fetchgit {
      url = "https://github.com/rxi/ini";
      rev = "13a254c9e38def8924a83badfea5eda5a01b9295";
      hash = "sha256-Eb/2Sfzyoo8Rpk6UoSoY5uDFxyd8Ar4E876O9JNfZ3Q=";
    };
  }
  {
    name = "N-V-__8AAEi9BgBKV3vzD6pzRAbfs1f7lNp1wsrArxR79lx6";
    path = fetchgit {
      url = "https://github.com/mjansson/rpmalloc";
      rev = "e4393ff85585d91400bcbad2e7266c011075b673";
      hash = "sha256-dE6shh2F3a+pu510Vw9icQvk2aAoPWYCtrIlT08fF3A=";
    };
  }
  {
    name = "N-V-__8AAMiwhADTFf225fEZAyMZ0m0uy3MKKpZbqgX5260R";
    path = fetchgit {
      url = "https://github.com/ocornut/imgui";
      rev = "b48d1afbe8ee8b238e2961dc363a949dd7304e23";
      hash = "sha256-PknWLxYuXQ73TCFN+eKOJDNLGbg/ZqKSF6mFxkJG6vI=";
    };
  }
  {
    name = "N-V-__8AAOcwBQBzPPchGzrzVG8hpgzRHXrUD-F_BDqCmAL3";
    path = fetchgit {
      url = "https://github.com/aklomp/base64";
      rev = "8bdda2d47caf8b066999c5bd01069e55bcd0d396";
      hash = "sha256-dIaNfQ/znpAdg0/vhVNTfoaG7c8eFrdDTI0QDHcghXU=";
    };
  }
  {
    name = "N-V-__8AAE7AEQBTD7426nSgryAEYEI64cHsD0WDKhNIfh6I";
    path = fetchgit {
      url = "https://github.com/mity/md4c";
      rev = "65c6c9d72cebd9a731aaa5597414ce04d9ea5de3";
      hash = "sha256-UMIebye8pQkiTjhbz3btTqPapzoqOnPHrtbPitc717A=";
    };
  }
  {
    name = "N-V-__8AAKOnKgCQ7Y0anxq1QC7BFhDSS2jHMk0yhGTeV2gh";
    path = fetchgit {
      url = "https://github.com/zeux/pugixml";
      rev = "c8033ce9d039e7f9d134877c363397b3cfe20816";
      hash = "sha256-gdfVktqG4Adcq1QvLyvx7EFV336gnNWXL+X/NOFJ0gs=";
    };
  }
  {
    name = "N-V-__8AAJPHSwBnLvtcY57RjGXHa9KuzDD5_55eeK9sC-F7";
    path = fetchgit {
      url = "https://github.com/htacg/tidy-html5";
      rev = "1ca37471b48a3498f985509828cb3cf85ea129f8";
      hash = "sha256-vzVWQodwzi3GvC9IcSQniYBsbkJV20iZanF33A0Gpe0=";
    };
  }

  # C/C++ header-only dependencies

  {
    name = "N-V-__8AAJKtAACXam4qGbql--FmlkH5sGRDUY6n_tqMfZW-";
    path = fetchgit {
      url = "https://github.com/kimgr/getopt_port";
      rev = "9d3d387087d252970923db7f297f681622c4e026";
      hash = "sha256-k8BXLDC4tup83BwU/UQ5PG2yFPiN7boInm1x6MizGYQ=";
    };
  }
  {
    name = "N-V-__8AADb7TQBhnAapR8-szphSk_8WmU22BY8jadPC_8-d";
    path = fetchgit {
      url = "https://github.com/nothings/stb";
      rev = "ae721c50eaf761660b4f90cc590453cdb0c2acd0";
      hash = "sha256-BIhbhXV7q5vodJ3N14vN9mEVwqrP6z9zqEEQrfLPzvI=";
    };
  }
  {
    name = "N-V-__8AAKQTAgC4IUwwDQSA3kMErF_02NAb-DgnNFymn_wr";
    path = fetchgit {
      url = "https://github.com/cubicdaiya/dtl";
      rev = "32567bb9ec704f09040fb1ed7431a3d967e3df03";
      hash = "sha256-s+syRiJhcxvmE0FBcbCi6DrL1hwu+0IJNMgg5Tldsv4=";
    };
  }
  {
    name = "N-V-__8AANqC8wBtv10C_41rBAgWfTMpQow7tzRi4h6LQYxm";
    path = fetchgit {
      url = "https://github.com/nlohmann/json";
      rev = "55f93686c01528224f448c19128836e7df245f72";
      hash = "sha256-cECvDOLxgX7Q9R3IE86Hj9JJUxraDQvhoyPDF03B2CY=";
    };
  }
  {
    name = "N-V-__8AAJ7xAABXU9I52yQSQ-zeeJEohtrHKj9ekUVZdlOR";
    path = fetchgit {
      url = "https://github.com/orlp/pdqsort";
      rev = "b1ef26a55cdb60d236a5cb199c4234c704f46726";
      hash = "sha256-xn3Jjn/jxJBckpg1Tx3HHVAWYPVTFMiDFiYgB2WX7Sc=";
    };
  }
  {
    name = "N-V-__8AAMg1AwAb5xteW1m8awWZwyssFBccTNB5WjAr2A9R";
    path = fetchgit {
      url = "https://github.com/GabTux/PPQSort";
      rev = "21c5a20ca3daf572caaf0a8522db32e27e28fa1d";
      hash = "sha256-HgM+p2QGd9C8A8l/VaEB+cLFDrY2HU6mmXyTNh7xd0A=";
    };
  }
  {
    name = "N-V-__8AAMC4CwDqHbQUv2a4lEr_UXtrXeW5CWU6X3mzDLo6";
    path = fetchgit {
      url = "https://github.com/martinus/robin-hood-hashing";
      rev = "7697343363af4cc3f42cab17be49e6af9ab181e2";
      hash = "sha256-17Mec4DC+BxgBVQSSxWldek7lDKCQ2Cmkjh7DKzppBk=";
    };
  }
  {
    name = "N-V-__8AAGS5UgB9tuEDsjOj_PBuqhvifei8hQNtCQwmN6g4";
    path = fetchgit {
      url = "https://github.com/Cyan4973/xxHash";
      rev = "a57f6cce2698049863af8c25787084ae0489d849";
      hash = "sha256-JlYhbyYvB7NnP/GaAjry4wro65bT32Lx6Isawi3YwNw=";
    };
  }
  {
    name = "N-V-__8AAKfAIADXrLp1KiOk6buhip0Z3uwW_uCBwir9ytK0";
    path = fetchgit {
      url = "https://github.com/unum-cloud/usearch";
      rev = "cc23bbaf21ef52313c5a495adbc40cbd733cdcfb";
      hash = "sha256-FsU/e8Aq+ARWV94c8MNJPL/edkde1Lj0cA3dOVrrm/0=";
    };
  }
  {
    name = "N-V-__8AAH8TBgB7tfUQiFJqV8veMMRCP4aM2xjP62YHbA7U";
    path = fetchgit {
      url = "https://github.com/Maratyszcza/FP16";
      rev = "3d2de1816307bac63c16a297e8c4dc501b4076df";
      hash = "sha256-CR7h1d9RFE86l6btk4N8vbQxy0KQDxSMvckbiO87JEg=";
    };
  }
]
