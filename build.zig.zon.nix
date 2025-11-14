{
  linkFarm,
  fetchzip,
  fetchgit,
}:
linkFarm "zig-packages" [
  {
    name = "capstone-6.0.0-Alpha4-tmNUgdI8AADDVL-qUUVmU0IGuFGpjz6-O7sBRjeB53yb";
    path = fetchgit {
      url = "https://github.com/allyourcodebase/capstone";
      rev = "90c3e2512286b077631da5361708562e333ae856";
      hash = "sha256-jqYbCviAAmW8XL45zpTKYKrupsa315KP0DGxVSgtqxE=";
    };
  }
  {
    name = "N-V-__8AAHAJ7QVuN5ADQLFxagK0PhxnQw9kUCjUDjFpjLbD";
    path = fetchzip {
      url = "https://github.com/capstone-engine/capstone/archive/refs/tags/6.0.0-Alpha4.tar.gz";
      hash = "sha256-8c/6QlRbII2LuJTnaGFwDT9HLiEkVD2+sUOEx3W4YfU=";
    };
  }
  {
    name = "nativefiledialog_extended-1.2.1-2-_pDry5gcAAA701XtymPdScWmrLQ5Zuw9yZYm_bxp7DkQ";
    path = fetchgit {
      url = "https://github.com/allyourcodebase/nativefiledialog-extended";
      rev = "dd47ba4b99b85c78f30a8faca0518ed913268c0a";
      hash = "sha256-S0AvXFtA82PJ4a9L+ES6Zvqux5Bz+urwBhjUcfqCkaQ=";
    };
  }
  {
    name = "N-V-__8AAN9tCgD3-w1k2cbga_852Tq67XM6_vfGQoHt_T5D";
    path = fetchgit {
      url = "https://github.com/btzy/nativefiledialog-extended";
      rev = "86d5f2005fe1c00747348a12070fec493ea2407e";
      hash = "sha256-GwT42lMZAAKSJpUJE6MYOpSLKUD5o9nSe9lcsoeXgJY=";
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
    name = "N-V-__8AAMSpeAAjIlPRk36GN81oqHOrwAtfmTZdOcDg42BM";
    path = fetchgit {
      url = "https://github.com/ocornut/imgui";
      rev = "44aa9a4b3a6f27d09a4eb5770d095cbd376dfc4b";
      hash = "sha256-9nFGXpVj+oWIfuOiXXVJodzc8G1hirSiVCMq6dxFV9o=";
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
    name = "N-V-__8AABchEAAlECji-MmwhoTDo_4aoyB1HkgVStV-vfho";
    path = fetchgit {
      url = "https://github.com/mity/md4c";
      rev = "729e6b8b320caa96328968ab27d7db2235e4fb47";
      hash = "sha256-2/wi7nJugR8X2J9FjXJF1UDnbsozGoO7iR295/KSJng=";
    };
  }
  {
    name = "N-V-__8AADXtKQAiMpWWNo5TPa37aXJx68JYsJq5gfycIjE_";
    path = fetchgit {
      url = "https://github.com/zeux/pugixml";
      rev = "ee86beb30e4973f5feffe3ce63bfa4fbadf72f38";
      hash = "sha256-t/57lg32KgKPc7qRGQtO/GOwHRqoj78lllSaE/A8Z9Q=";
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
    name = "N-V-__8AALk1AwB_-PJsG-Q9F1OHqaGovuaHaqFCkhppJHXw";
    path = fetchgit {
      url = "https://github.com/GabTux/PPQSort";
      rev = "249da1c63b06824befc4ed643b883328cfdd6ba0";
      hash = "sha256-EMZVI/uyzwX5637/rdZuMZoql5FTrsx0ESJMdLVDmfk=";
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
    name = "N-V-__8AALyEGwBlGkgGPJC0wE0QWREXnRMzoGRJ7-BspmtR";
    path = fetchgit {
      url = "https://github.com/unum-cloud/usearch";
      rev = "bda207cca92e130cfc2c39065681c75a70f0e32d";
      hash = "sha256-jzSwS4AxcRbl32fkUA6lHz3E5zykwvqzstR/yBs3z3c=";
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
