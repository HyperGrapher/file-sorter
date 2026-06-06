#include <ctype.h>
#include <dirent.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

#ifdef _WIN32
#include <direct.h>
#include <io.h>
#define PATH_SEP '\\'
#define MKDIR(path) _mkdir(path)
#define access _access
#define F_OK 0
#else
#include <unistd.h>
#define PATH_SEP '/'
#define MKDIR(path) mkdir(path, 0755)
#endif

#ifndef PATH_MAX
#define PATH_MAX 4096
#endif

#define MAX_SUFFIX_ATTEMPTS 10000

typedef struct {
    const char *ext;
    const char *folder;
} Rule;

static const Rule rules[] = {
    {".jpg", "Images"},       {".jpeg", "Images"},
    {".png", "Images"},       {".gif", "Images"},
    {".bmp", "Images"},       {".webp", "Images"},
    {".svg", "Images"},       {".heic", "Images"},

    {".txt", "Documents"},    {".pdf", "Documents"},
    {".doc", "Documents"},    {".docx", "Documents"},
    {".xls", "Documents"},    {".xlsx", "Documents"},
    {".ppt", "Documents"},    {".pptx", "Documents"},
    {".md", "Documents"},     {".rtf", "Documents"},
    {".csv", "Documents"},    {".html", "Documents"},
    {".htm", "Documents"},

    {".mp4", "Videos"},       {".mkv", "Videos"},
    {".mov", "Videos"},       {".avi", "Videos"},
    {".webm", "Videos"},      {".wmv", "Videos"},
    {".flv", "Videos"},

    {".mp3", "Music"},        {".wav", "Music"},
    {".flac", "Music"},       {".aac", "Music"},
    {".ogg", "Music"},        {".m4a", "Music"},

    {".zip", "Archives"},     {".rar", "Archives"},
    {".7z", "Archives"},      {".tar", "Archives"},
    {".gz", "Archives"},      {".xz", "Archives"},
    {".bz2", "Archives"},

    {".exe", "Installers"},   {".msi", "Installers"},
    {".pkg", "Installers"},   {".dmg", "Installers"},
    {".deb", "Installers"},   {".rpm", "Installers"},
    {".apk", "Installers"},   {".appimage", "Installers"},
    {".msixbundle", "Installers"},

    {".torrent", "Torrents"},

    {".c", "Code"},           {".h", "Code"},
    {".cpp", "Code"},         {".hpp", "Code"},
    {".py", "Code"},          {".js", "Code"},
    {".ts", "Code"},          {".java", "Code"},
    {".cs", "Code"},          {".go", "Code"},
    {".rs", "Code"},          {".swift", "Code"},
    {".json", "Code"},        {".xml", "Code"},
    {".ini", "Code"},         {".yaml", "Code"},
    {".yml", "Code"},

    {NULL, NULL}
};

static int equals_ignore_case(const char *a, const char *b) {
    while (*a && *b) {
        if (tolower((unsigned char)*a) != tolower((unsigned char)*b)) {
            return 0;
        }
        a++;
        b++;
    }
    return *a == '\0' && *b == '\0';
}

static const char *get_extension(const char *filename) {
    const char *dot = strrchr(filename, '.');
    if (dot == NULL || dot == filename || dot[1] == '\0') {
        return NULL;
    }
    return dot;
}

static const char *find_folder(const char *ext) {
    int i;

    if (ext == NULL) {
        return "Others";
    }

    for (i = 0; rules[i].ext != NULL; i++) {
        if (equals_ignore_case(ext, rules[i].ext)) {
            return rules[i].folder;
        }
    }
    return "Others";
}

static int path_join(char *out, size_t out_size, const char *left, const char *right) {
    size_t len = strlen(left);
    char sep[2] = "";

    if (len > 0 && left[len - 1] != '/' && left[len - 1] != '\\') {
        sep[0] = PATH_SEP;
        sep[1] = '\0';
    }

    return snprintf(out, out_size, "%s%s%s", left, sep, right) < (int)out_size;
}

static void trim_trailing_separators(char *path) {
    size_t len = strlen(path);

    while (len > 1 && (path[len - 1] == '/' || path[len - 1] == '\\')) {
        path[len - 1] = '\0';
        len--;
    }
}

static int is_regular_file(const char *path) {
    struct stat st;

    if (stat(path, &st) != 0) {
        return 0;
    }
    return S_ISREG(st.st_mode);
}

static int ensure_dir(const char *path, int dry_run) {
    struct stat st;

    if (stat(path, &st) == 0) {
        return S_ISDIR(st.st_mode) ? 0 : -1;
    }

    if (dry_run) {
        return 0;
    }

    if (MKDIR(path) != 0 && errno != EEXIST) {
        return -1;
    }

    return 0;
}

static int make_unique_destination(char *dest, size_t dest_size, const char *dir, const char *name) {
    const char *dot = get_extension(name);
    char base[PATH_MAX];
    char candidate[PATH_MAX];
    int i;

    if (!path_join(dest, dest_size, dir, name)) {
        return -1;
    }

    if (access(dest, F_OK) != 0) {
        return 0;
    }

    if (dot == NULL) {
        if (snprintf(base, sizeof(base), "%s", name) >= (int)sizeof(base)) {
            return -1;
        }
        dot = "";
    } else {
        size_t base_len = (size_t)(dot - name);
        if (base_len >= sizeof(base)) {
            return -1;
        }
        memcpy(base, name, base_len);
        base[base_len] = '\0';
    }

    for (i = 1; i < MAX_SUFFIX_ATTEMPTS; i++) {
        if (snprintf(candidate, sizeof(candidate), "%s (%d)%s", base, i, dot) >= (int)sizeof(candidate)) {
            return -1;
        }
        if (!path_join(dest, dest_size, dir, candidate)) {
            return -1;
        }
        if (access(dest, F_OK) != 0) {
            return 0;
        }
    }

    return -1;
}

static int default_downloads_dir(char *out, size_t out_size) {
    const char *home = NULL;

#ifdef _WIN32
    home = getenv("USERPROFILE");
#else
    home = getenv("HOME");
#endif

    if (home == NULL || home[0] == '\0') {
        return -1;
    }

    return path_join(out, out_size, home, "Downloads") ? 0 : -1;
}

static void print_usage(const char *program) {
    printf("Usage: %s [--dry-run] [folder]\n", program);
    printf("Sorts files into Images, Documents, Videos, Music, Archives, Installers, Torrents, Code, and Others.\n");
}

int main(int argc, char **argv) {
    char target_dir[PATH_MAX];
    DIR *dir;
    struct dirent *entry;
    int dry_run = 0;
    int moved = 0;
    int skipped = 0;
    int errors = 0;
    int i;

    target_dir[0] = '\0';

    for (i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--dry-run") == 0 || strcmp(argv[i], "-n") == 0) {
            dry_run = 1;
        } else if (strcmp(argv[i], "--help") == 0 || strcmp(argv[i], "-h") == 0) {
            print_usage(argv[0]);
            return 0;
        } else if (target_dir[0] == '\0') {
            if (snprintf(target_dir, sizeof(target_dir), "%s", argv[i]) >= (int)sizeof(target_dir)) {
                fprintf(stderr, "Path is too long.\n");
                return 1;
            }
        } else {
            fprintf(stderr, "Unexpected argument: %s\n", argv[i]);
            print_usage(argv[0]);
            return 1;
        }
    }

    if (target_dir[0] == '\0' && default_downloads_dir(target_dir, sizeof(target_dir)) != 0) {
        fprintf(stderr, "Could not find your Downloads folder. Pass a folder path explicitly.\n");
        return 1;
    }

    trim_trailing_separators(target_dir);
    dir = opendir(target_dir);
    if (dir == NULL) {
        fprintf(stderr, "Could not open folder '%s': %s\n", target_dir, strerror(errno));
        return 1;
    }

    printf("%s %s\n", dry_run ? "Previewing" : "Sorting", target_dir);

    while ((entry = readdir(dir)) != NULL) {
        char src[PATH_MAX];
        char category_dir[PATH_MAX];
        char dest[PATH_MAX];
        const char *folder;

        if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0) {
            continue;
        }

        if (!path_join(src, sizeof(src), target_dir, entry->d_name)) {
            fprintf(stderr, "Skipping long path: %s\n", entry->d_name);
            errors++;
            continue;
        }

        if (!is_regular_file(src)) {
            skipped++;
            continue;
        }

        folder = find_folder(get_extension(entry->d_name));

        if (!path_join(category_dir, sizeof(category_dir), target_dir, folder)) {
            fprintf(stderr, "Skipping long category path for: %s\n", entry->d_name);
            errors++;
            continue;
        }

        if (ensure_dir(category_dir, dry_run) != 0) {
            fprintf(stderr, "Could not create folder '%s': %s\n", category_dir, strerror(errno));
            errors++;
            continue;
        }

        if (make_unique_destination(dest, sizeof(dest), category_dir, entry->d_name) != 0) {
            fprintf(stderr, "Could not build destination for: %s\n", entry->d_name);
            errors++;
            continue;
        }

        printf("%s %s -> %s\n", dry_run ? "Would move" : "Moving", entry->d_name, folder);

        if (!dry_run && rename(src, dest) != 0) {
            fprintf(stderr, "Could not move '%s': %s\n", entry->d_name, strerror(errno));
            errors++;
            continue;
        }

        moved++;
    }

    closedir(dir);

    printf("\nDone. %s: %d, skipped: %d, errors: %d\n",
           dry_run ? "would move" : "moved", moved, skipped, errors);

    return errors == 0 ? 0 : 1;
}
