#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

static void make_directory(const char *path) {
  char buffer[PATH_MAX];
  size_t length = strlen(path);

  if (length >= sizeof(buffer)) {
    exit(2);
  }

  memcpy(buffer, path, length + 1);
  for (char *cursor = buffer + 1; *cursor; ++cursor) {
    if (*cursor == '/') {
      *cursor = '\0';
      if (mkdir(buffer, 0755) != 0 && errno != EEXIST) {
        exit(3);
      }
      *cursor = '/';
    }
  }
  if (mkdir(buffer, 0755) != 0 && errno != EEXIST) {
    exit(3);
  }
}

int main(int argc, char **argv) {
  const char *prefix = NULL;
  for (int index = 1; index + 1 < argc; ++index) {
    if (strcmp(argv[index], "--prefix") == 0) {
      prefix = argv[index + 1];
    }
  }

  if (prefix == NULL) {
    return 1;
  }

  make_directory(prefix);
  char documentation[PATH_MAX];
  if (snprintf(documentation, sizeof(documentation), "%s/docs", prefix) >=
      (int)sizeof(documentation)) {
    return 2;
  }
  make_directory(documentation);

  char asset[PATH_MAX];
  if (snprintf(asset, sizeof(asset), "%s/asset with spaces.png",
               documentation) >= (int)sizeof(asset)) {
    return 2;
  }
  FILE *asset_file = fopen(asset, "w");
  if (asset_file == NULL) {
    return 4;
  }
  fclose(asset_file);

  char executable[PATH_MAX];
  if (snprintf(executable, sizeof(executable), "%s/ida", prefix) >=
      (int)sizeof(executable)) {
    return 2;
  }

  FILE *file = fopen(executable, "w");
  if (file == NULL) {
    return 4;
  }
  fputs("#!/bin/sh\nprintf 'fixture:%s\\n' \"$IDAUSR\"\n", file);
  fclose(file);
  return chmod(executable, 0755) == 0 ? 0 : 5;
}
