#! /bin/sh
# Creates the symlinks listed in links. Existing files that aren't symlinks are left alone.
# In directories filled from a source/* entry, removes symlinks into that source whose target
# no longer exists, such as a skill that was moved or deleted.

link() {
	if [ -e "$2" ] && [ ! -L "$2" ]; then
		echo "skip: $2 exists (not a symlink)"
	else
		ln -s -f -n "$1" "$2"
	fi
}

prune() {
	for l in "$1"/*; do
		[ -L "$l" ] && [ ! -e "$l" ] || continue
		case "$(readlink "$l")" in
		"$2"/*)
			rm "$l"
			echo "removed: $l"
			;;
		esac
	done
}

grep -v -e '^#' -e '^[[:space:]]*$' ~/.dotfiles/links | while read -r src dst only; do
	[ "$only" = windows ] && continue
	case "$src" in
	*/\*)
		mkdir -p ~/"$dst"
		prune ~/"$dst" ~/.dotfiles/"${src%/\*}"
		for dir in ~/.dotfiles/"${src%\*}"*/; do
			link "${dir%/}" ~/"$dst"/"$(basename "$dir")"
		done
		;;
	*)
		mkdir -p "$(dirname ~/"$dst")"
		link ~/.dotfiles/"$src" ~/"$dst"
		;;
	esac
done
