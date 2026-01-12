mcsymlink.sh

A small helper script for creating and removing common Minecraft symlinks from a
".minecraft" directory (schematics, saves, screenshots, resourcepacks).

Usage

  Run interactively (default):
    mcsymlink.sh

  Non-interactive flags (run from inside a .minecraft or minecraft directory):
    -d, --dry-run        Show what would be done, do not perform any changes
    -f, --force          Replace existing links when creating a symlink
    -v, --verbose        Be more verbose about what the script is doing
    -h, --help           Show this help message and exit

    -m, --make <name>    Make the named symlink (schematics|saves|screenshots|resourcepacks|all)
    -u, --unlink <name>  Unlink the named symlink (or 'all')
    -r, --rmdir <name>   Remove an (empty) directory in the current directory
    -q, --quit           Quit immediately (useful for non-interactive scripts)

Examples

  Interactive menu (default):
    mcsymlink.sh

  Dry-run a make operation:
    mcsymlink.sh --make saves -d

  Create/replace a symlink non-interactively:
    mcsymlink.sh --make saves -f

  Remove a symlink non-interactively:
    mcsymlink.sh --unlink saves

Logging

  Actions are appended to `mcsymlink.log` in the directory where the script is run. Dry-run operations are recorded with a "[DRY RUN]" prefix.

Notes

  - The short dry-run option was changed from `-n` to `-d`. The test-suite has been updated to reflect this.
  - Run the script from the `.minecraft` directory (it will exit with an error otherwise).
