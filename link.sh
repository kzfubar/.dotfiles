#! /bin/sh
# Creates the symlinks listed in links. Existing files that aren't symlinks are left alone.

link() {
	if [ -e "$2" ] && [ ! -L "$2" ]; then
		echo "skip: $2 exists (not a symlink)"
	else
		ln -s -f -n "$1" "$2"
	fi
}

grep -v -e '^#' -e '^[[:space:]]*$' ~/.dotfiles/links | while read -r src dst only; do
	[ "$only" = windows ] && continue
	case "$src" in
	*/\*)
		mkdir -p ~/"$dst"
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
