#!/usr/bin/env bash

# ------------------------------------------------------------------------------
#  minecraft_symlinks.sh
# ------------------------------------------------------------------------------
#    A script by FeedTheChunk 4-16-2024 with help from Hypnotized
# ------------------------------------------------------------------------------
# A script to make and remove symlinks for minecraft a little easier
# Adds symlinks for the following directories:
#   schematics
#   saves
#   resourcepacks
#   screenshots
# ------------------------------------------------------------------------------

# Load the constants file (optional)
. "$HOME"/bin/constants.sh 2>/dev/null || true
. "$HOME"/constants.sh 2>/dev/null || true

# Enable strict mode for safer execution; keep IFS conservative
set -o errexit -o nounset -o pipefail
IFS=$'\n\t'

# Ensure color/format variables exist so script works even without constants.sh
: "${COLOR_OFF:=}"
: "${BBLUE:=}"
: "${IYELLOW:=}"
: "${IGREEN:=}"
: "${BRED:=}"
: "${RED:=}"
: "${BLUE:=}"
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
#  FUNCTIONS
# mksymlink: create a symlink at the current directory pointing to the target
# $1 - target path (destination for the symlink)
# $2 - link name (relative name in current directory)
mksymlink()
{
	local target="$1"
	local linkname="$CUR_DIR/$2"

	verbose "mksymlink: target=$target linkname=$linkname"
	echo -e "Making $BBLUE$2$COLOR_OFF symlink"
	if [[ -e "$linkname" ]]; then
		if [[ "$FORCE" == "true" ]]; then
			echo -e "$IYELLOW $linkname exists; removing due to --force$COLOR_OFF"
			if [[ "$DRY_RUN" == "true" ]]; then
				echo -e "$IYELLOW [DRY RUN] unlink $linkname$COLOR_OFF"
			else
				unlink "$linkname" || { echo -e "$RED Failed to remove existing $linkname$COLOR_OFF" >&2; return; }
			fi
		else
			echo -e "$IYELLOW $linkname already exists; skipping (use --force to replace)$COLOR_OFF"
			return
		fi
	fi

	if [[ "$DRY_RUN" == "true" ]]; then
		printf '%b\n' "$IYELLOW [DRY RUN] ln -s \"$target\" \"$linkname\"$COLOR_OFF"
		log_change "[DRY RUN] Would create symlink '$linkname' -> '$target'"
	else
		if ln -vs "$target" "$linkname"; then
			log_change "Created symlink '$linkname' -> '$target'"
		else
			log_change "ERROR: Failed to create symlink '$linkname' -> '$target'"
			return 1
		fi
	fi
	sleep "$wait_time"
}

# delink: remove a symlink in the current directory
# $1 - link name
delink()
{
	local linkname="$CUR_DIR/$1"
	verbose "delink: linkname=$linkname"
	if [[ -L "$linkname" ]]; then
		if [[ "$DRY_RUN" == "true" ]]; then
			echo -e "$IYELLOW [DRY RUN] unlink $linkname$COLOR_OFF"
			log_change "[DRY RUN] Would remove symlink '$linkname'"
		else
			if unlink "$linkname"; then
				echo -e "Successfully removed symlink $BBLUE$1$COLOR_OFF"
				log_change "Removed symlink '$linkname'"
			else
				echo -e "$RED Failed to remove symlink $1$COLOR_OFF" >&2
				log_change "ERROR: Failed to remove symlink '$linkname'"
			fi
		fi
	else
		echo -e "$IYELLOW No symlink $linkname found$COLOR_OFF"
	fi
	sleep "$wait_time"
}

# rm_dir: remove an (empty) directory in the current directory
# $1 - directory name
rm_dir()
{
	local dirpath="$CUR_DIR/$1"
	verbose "rm_dir: dirpath=$dirpath"
	echo -e "Directory exists. $BRED Removing $1.$COLOR_OFF CTRL+C to break."
	sleep 5
	if [[ "$DRY_RUN" == "true" ]]; then
		echo -e "$IYELLOW [DRY RUN] rmdir $dirpath$COLOR_OFF"
		log_change "[DRY RUN] Would remove directory '$dirpath'"
	else
		if rmdir "$dirpath"; then
			log_change "Removed directory '$dirpath'"
		else
			echo -e "$RED Failed to remove directory $dirpath$COLOR_OFF" >&2
			log_change "ERROR: Failed to remove directory '$dirpath'"
			exit 1
		fi
	fi
	sleep "$wait_time"
}

# manage_symlink: Ensure or update a symlink for a given local name
# $1 - local name (e.g., schematics)
# $2 - target directory (full path to where to point the symlink)
manage_symlink()
{
	local local_name="$1"
	local target_dir="$2"
	verbose "manage_symlink: local_name=$local_name target_dir=$target_dir"

	if [[ -L "$CUR_DIR/$local_name" ]]; then
		read -rp "Do you want to unlink \"$CUR_DIR/$local_name\"? [Y/n] " choice
		case "${choice:-Y}" in
			[nN]|[nN][oO])
				verbose "user chose not to unlink $local_name"
				return
				;;
			*)
				delink "$local_name"
				;;
		esac
	else
		if [[ -d "$CUR_DIR/$local_name" ]]; then
			rm_dir "$local_name"
		fi
	fi

	# Create the symlink
	mksymlink "$target_dir" "$local_name"
}

# Print help/usage text
print_help()
{
	echo -e "$IYELLOW"
	cat <<'USAGE'
  Usage: mcsymlink.sh [options]

  Options:
    -d, --dry-run        Show what would be done, do not perform any changes
    -f, --force          Replace existing links when creating a symlink (non-interactive replace)
    -v, --verbose        Be more verbose about what the script is doing
    -h, --help           Show this help message and exit

    -m, --make <name>    Make the named symlink (schematics|saves|screenshots|resourcepacks|all)
    -u, --unlink <name>  Unlink the named symlink (or 'all')
    -r, --rmdir <name>   Remove an (empty) directory in the current directory
    -q, --quit           Quit immediately (useful for non-interactive scripts)

  Examples:
    mcsymlink.sh                   # run interactive menu (default)
    mcsymlink.sh -d                # dry-run mode
    mcsymlink.sh -f                # force mode (interactive)
    mcsymlink.sh --make saves -f   # non-interactive: create 'saves', replacing existing path
    mcsymlink.sh --unlink saves    # non-interactive: remove 'saves' symlink
    mcsymlink.sh --rmdir screenshots -d  # dry-run rmdir
    mcsymlink.sh --quit            # non-interactive: exit successfully

  Note:
    Actions are logged to `mcsymlink.log` in the directory where the script is run.
USAGE
	echo -e "$COLOR_OFF"
}

# UI helpers
verbose()
{
	if [[ "${VERBOSE:-false}" == "true" ]]; then
		printf '%b\n' "${IYELLOW}[VERBOSE] ${*}${COLOR_OFF}"
	fi
}

# log_change: append a timestamped message to mcsymlink.log in the current working directory
# Usage: log_change "Message text"
log_change()
{
	local msg="$*"
	local stamp
	# stamp=$(date '+%Y-%m-%d %H:%M:%S %z')
	stamp=$(date '+%b-%d-%Y %H:%M:%S')
	local logfile="${CUR_DIR:-$(pwd -P)}/mcsymlink.log"
	printf '[%s] %s\n' "$stamp" "$msg" >> "$logfile"
}

print_header()
{
	echo -e "$IYELLOW"
	echo -e " *****************************************************"
	echo -e " **                                                 **"
	echo -e " ** MINECRAFT SYMLINK DIRECTORY CREATOR and REMOVER **"
	echo -e " **                                                 **"
	echo -e " *****************************************************"
	echo -e "$COLOR_OFF"
}

print_menu()
{
	# Color Dry Run and Verbose based on their boolean values
	local dry_color dry_val verbose_color verbose_val
	if [[ "${DRY_RUN:-false}" == "true" ]]; then
		dry_color="$BLUE"
		dry_val="On"
	else
		dry_color="$RED"
		dry_val="Off"
	fi
	if [[ "${VERBOSE:-false}" == "true" ]]; then
		verbose_color="$BLUE"
		verbose_val="On"
	else
		verbose_color="$RED"
		verbose_val="Off"
	fi
	echo -e "             Dry Run: ${dry_color}${dry_val}${COLOR_OFF} Verbose: ${verbose_color}${verbose_val}"
	echo -e "$COLOR_OFF"

	echo -e "  1. Make$IGREEN schematics$COLOR_OFF symlink"
	echo -e "  2. Make$IGREEN saves$COLOR_OFF symlink"
	echo -e "  3. Make$IGREEN screenshots$COLOR_OFF symlink"
	echo -e "  4. Make$IGREEN resourcepacks$COLOR_OFF symlink"
	echo -e "  A. Make$IGREEN ALL$COLOR_OFF symlinks"
	echo
	echo -e "  5. Unlink$IYELLOW schematics$COLOR_OFF symlink"
	echo -e "  6. Unlink$IYELLOW saves$COLOR_OFF symlink"
	echo -e "  7. Unlink$IYELLOW screenshots$COLOR_OFF symlink"
	echo -e "  8. Unlink$IYELLOW resourcepacks$COLOR_OFF symlink"
	echo -e "  U. Unlink$IGREEN ALL$COLOR_OFF symlinks"
	echo
	echo -e "  Q.$RED Do nothing and quit$COLOR_OFF"
	echo -e "  V.$RED Toggle Verbose mode$COLOR_OFF"
	echo -e "  D.$RED Toggle Dry Run$COLOR_OFF"
}

handle_choice()
{
	local choice="$1"
	case "$choice" in
		1)
			manage_symlink schematics "$SCHEMATICS_DIR"
			;;
		2)
			manage_symlink saves "$SAVE_DIR"
			;;
		3)
			manage_symlink screenshots "$SCREENSHOTS_DIR"
			;;
		4)
			manage_symlink resourcepacks "$RESOURCE_DIR"
			;;
		5)
			delink schematics
			;;
		6)
			delink saves
			;;
		7)
			delink screenshots
			;;
		8)
			delink resourcepacks
			;;
		"a" | "A")
			manage_symlink schematics "$SCHEMATICS_DIR"
			manage_symlink saves "$SAVE_DIR"
			manage_symlink screenshots "$SCREENSHOTS_DIR"
			manage_symlink resourcepacks "$RESOURCE_DIR"
			;;
		"u" | "U")
			delink schematics
			delink saves
			delink screenshots
			delink resourcepacks
			;;
		"q" | "Q")
			echo "Goodbye."
			return 1
			;;
		"v" | "V")
			if [[ "$VERBOSE" == "true" ]]; then
				VERBOSE=false
			else
				VERBOSE=true
			fi
			;;
		"d" | "D")
			if [[ "$DRY_RUN" == "true" ]]; then
				DRY_RUN=false
			else
				DRY_RUN=true
			fi
			;;
		*) ;;
	esac
	return 0
}

# If a non-interactive action was requested, resolve and run it; otherwise continue
run_non_interactive()
{
	# Run in non-interactive mode (no prompts or menu)
	NONINTERACTIVE=true
	# Resolve a friendly name to a directory
	resolve_target()
	{
		case "$1" in
			schematics) echo "$SCHEMATICS_DIR" ;;
			saves) echo "$SAVE_DIR" ;;
			screenshots) echo "$SCREENSHOTS_DIR" ;;
			resourcepacks|resourcepack|resource) echo "$RESOURCE_DIR" ;;
			all) echo "ALL" ;;
			*) echo "" ;;
		esac
	}

	# --quit requested
	if [[ "${QUIT:-false}" == "true" ]]; then
		verbose "Quit mode requested; exiting."
		exit 0
	fi

	# Do MAKE
	if [[ -n "${MAKE_ACTION:-}" ]]; then
		target=$(resolve_target "$MAKE_ACTION")
		if [[ "$target" == "ALL" ]]; then
			manage_symlink schematics "$SCHEMATICS_DIR"
			manage_symlink saves "$SAVE_DIR"
			manage_symlink screenshots "$SCREENSHOTS_DIR"
			manage_symlink resourcepacks "$RESOURCE_DIR"
		else
			if [[ -z "$target" ]]; then
				echo -e "$RED Unknown name for --make: $MAKE_ACTION$COLOR_OFF" >&2
				exit 2
			fi
			# Non-interactive replacement logic: avoid prompting
			local existing="$CUR_DIR/$MAKE_ACTION"
			if [[ -L "$existing" ]]; then
			if [[ "$FORCE" == "true" ]]; then
				verbose "Non-interactive: removing existing symlink $existing"
				delink "$MAKE_ACTION"
			else
				echo -e "$IYELLOW $MAKE_ACTION already exists as symlink; use --force to replace$COLOR_OFF"
					exit 1
				fi
			elif [[ -d "$existing" ]]; then
				if [[ "$FORCE" == "true" ]]; then
					verbose "Non-interactive: removing existing directory $existing"
					rm_dir "$MAKE_ACTION"
				else
					echo -e "$IYELLOW $MAKE_ACTION already exists as directory; use --force to replace$COLOR_OFF"
					exit 1
				fi
			fi
			# Create the symlink now
			mksymlink "$target" "$MAKE_ACTION"
		fi
		exit 0
	fi

	# Do UNLINK
	if [[ -n "${UNLINK_ACTION:-}" ]]; then
		if [[ "${UNLINK_ACTION}" == "all" ]]; then
			delink schematics
			delink saves
			delink screenshots
			delink resourcepacks
		else
			delink "$UNLINK_ACTION"
		fi
		exit 0
	fi

	# Do RMDIR
	if [[ -n "${RMDIR_ACTION:-}" ]]; then
		target=$(resolve_target "$RMDIR_ACTION")
		if [[ "$target" == "ALL" ]]; then
			rm_dir schematics
			rm_dir saves
			rm_dir screenshots
			rm_dir resourcepacks
		else
			if [[ -z "$target" ]]; then
				echo -e "$RED Unknown name for --rmdir: $RMDIR_ACTION$COLOR_OFF" >&2
				exit 2
			fi
			rm_dir "$RMDIR_ACTION"
		fi
		exit 0
	fi
}
# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# VARIABLES
DRY_RUN=false
FORCE=false
VERBOSE=false
basedir=$(basename "$(pwd)")
CUR_DIR=$(pwd -P)
SAVE_DIR="$HOME/.minecraft/symlinks/saves/"
RESOURCE_DIR="$HOME/.minecraft/symlinks/resourcepacks/"
SCHEMATICS_DIR="$HOME/.minecraft/symlinks/schematics/"
SCREENSHOTS_DIR="$HOME/.minecraft/symlinks/screenshots/"
wait_time=2 # Used to slow down the script so that we have time read the terminal

# Parse command-line options (non-interactive flags)
# -d, --dry-run    : show actions but don't perform them
# -f, --force      : force creation (replace existing link)
# -v, --verbose    : be verbose
# -h, --help       : print help and exit
if command -v getopt >/dev/null 2>&1; then
	PARSED=$(getopt -o dfhvm:u:r:q --long dry-run,force,help,verbose,make:,unlink:,rmdir:,quit -- "$@") || exit 2
	eval set -- "$PARSED"
	while true; do
		case "$1" in
			-d|--dry-run)
				DRY_RUN=true; shift ;;
			-f|--force)
				FORCE=true; shift; ;;
			-v|--verbose)
				VERBOSE=true; shift ;;
			-m|--make)
				MAKE_ACTION="$2"; shift 2 ;;
			-u|--unlink)
				UNLINK_ACTION="$2"; shift 2 ;;
			-r|--rmdir)
				RMDIR_ACTION="$2"; shift 2 ;;
			-q|--quit)
				QUIT=true; shift ;;
			-h|--help)
				print_help
				exit 0 ;;
			--) shift; break ;;
			*) break ;;
		esac
	done
fi

# echo "$basedir"
if [[ "$basedir" != .minecraft && "$basedir" != minecraft ]]; then
	echo -e "$RED Error: This script MUST be run from the .minecraft or minecraft directory." >&2
	exit 1
fi

# If non-interactive flags were provided, run them and exit
if [[ -n "${MAKE_ACTION:-}" || -n "${UNLINK_ACTION:-}" || -n "${RMDIR_ACTION:-}" || "${QUIT:-false}" == "true" ]]; then
	print_header
	run_non_interactive
	exit 0
fi

# MAIN LOOP
while true; do
	clear
	print_header
	print_menu
	read -rp 'Select an option: ' mainchoice
	if ! handle_choice "$mainchoice"; then
		break
	fi
done

exit 0
