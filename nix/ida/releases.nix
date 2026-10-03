{
  default = "9.5.261001";

  versions = {
    "9.5.261001" = {
      version = "9.5.261001";
      pythonPackage = "python314";
      installers = {
        x86_64-linux = {
          name = "ida-pro_95_x64linux.run";
          hash = "sha256-PEM3yU/SkLiNlZN6DLOPg1J4zIznv+iLah9iaZ6QSBE=";
        };
        aarch64-darwin = {
          name = "ida-pro_95_armmac.app.zip";
          hash = "sha256-yiqs8IBebgpyOaKFuHEXcFQJ8dx00PtBqH1H14YnNHU=";
        };
      };
    };

    "9.4.260714" = {
      version = "9.4.260714";
      pythonPackage = "python314";
      installers.x86_64-linux = {
        name = "ida-pro_94_x64linux.run";
        hash = "sha256-6rtkw8hJ04WHWVWDWenOvPF+KpG8xgUjUz34uERiqlQ=";
      };
    };

    "9.2.250908" = {
      version = "9.2.250908";
      pythonPackage = "python314";
      installers.x86_64-linux = {
        name = "ida-pro_92_x64linux.run";
        hash = "sha256-qt0PiulyuE+U8ql0g0q/FhnzvZM7O02CdfnFAAjQWuE=";
      };
    };
  };
}
