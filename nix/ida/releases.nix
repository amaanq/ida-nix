{
  default = "9.4.260714";

  versions = {
    "9.4.260714" = {
      version = "9.4.260714";
      installerName = "ida-pro_94_x64linux.run";
      installerHash = "sha256-6rtkw8hJ04WHWVWDWenOvPF+KpG8xgUjUz34uERiqlQ=";
      pythonPackage = "python314";
      systems = [ "x86_64-linux" ];
    };

    "9.2.250908" = {
      version = "9.2.250908";
      installerName = "ida-pro_92_x64linux.run";
      installerHash = "sha256-qt0PiulyuE+U8ql0g0q/FhnzvZM7O02CdfnFAAjQWuE=";
      pythonPackage = "python314";
      systems = [ "x86_64-linux" ];
    };
  };
}
