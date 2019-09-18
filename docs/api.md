<h1>API</h1>

Besides the default hook implementations which are available to you from your
`ellipsis.sh` as `hooks.<name>`, there are a number of useful functions and
variables which ellipsis exposes for you:

#### Index
| Function/Variable           | Description                                                                          |
|-----------------------------|--------------------------------------------------------------------------------------|
| `ellipsis.each`             | Executes command for each installed package.                                         |
| `ellipsis.list_packages`    | Lists all installed packages.                                                        |
| `fs.backup`                 | Creates a backup of an existing file, ensuring you don't overwrite existing backups. |
| `fs.file_exists`            | Returns true if file exists.                                                         |
| `fs.folder_empty`           | Returns true if folder is empty.                                                     |
| `fs.is_broken_symlink`      | Returns true if file is a broken symlink.                                            |
| `fs.is_ellipsis_symlink`    | Returns true if file is a symlink pointing to an ellipsis package.                   |
| `fs.is_symlink`             | Returns true if file is a symlink.                                                   |
| `fs.link_rfile`             | Symlinks a single file.                                                              |
| `fs.link_file`              | Symlinks a single file and prepends a dot.                                           |
| `fs.link_rfiles`            | Symlinks all files in a given folder.                                                |
| `fs.link_files`             | Symlinks all files in a given folder and prepends a dot.                             |
| `fs.list_dirs`              | Lists directories, useful for passing subdirectories to `fs.link_files`.             |
| `fs.list_symlinks`          | Lists symlinks in a folder, defaulting to `$ELLIPSIS_HOME`.                          |
| `fs.strip_dot`              | Removes `.` prefix from files in a given directory.                                  |
| `fs.source_first`           | Sources (and echo's) first file found.                                               |
| `git.behind`                | Prints number of commits local is behind remote.                                     |
| `git.clone`                 | Clones a Git repo, identical to `git clone`.                                         |
| `git.diffstat`              | Displays `git diff --stat`.                                                          |
| `git.status`                | Displays `git status -s`.                                                            |
| `git.has_changes`           | Returns true if repository has changes.                                              |
| `git.has_untracked`         | Returns true if repository has untracked files.                                      |
| `git.head`                  | Prints how far ahead a package is from origin.                                       |
| `git.is_behind`             | Returns true if local repository is behind the remote.                               |
| `git.last_updated`          | Prints commit's relative last update time.                                           |
| `git.pull`                  | Identical to `git pull`.                                                             |
| `git.push`                  | Identical to `git push`.                                                             |
| `git.sha1`                  | Prints last commit's sha1 using `git rev-parse --short HEAD`.                        |
| `os.platform`               | Returns one of `cygwin`, `freebsd`, `linux`, `osx`.                                  |
| `path.abs_path`             | Return absolute path to `$1`.                                                        |
| `path.is_path`              | Simple heuristic to determine if `$1` is a path.                                     |
| `path.relative_to_home`     | Replaces `$HOME` with `~`                                                            |
| `path.expand`               | Replaces `~` with `$HOME`                                                            |
| `path.relative_to_packages` | Strips `$ELLIPSIS_PACKAGES` from path.                                               |
| `path.strip_dot`            | Strip dot from hidden files/folders.                                                 |
| `utils.cmd_exists`          | Returns true if command exists.                                                      |
| `utils.is_interactive`      | Returns true if ellipsis is running in an interactive terminal.                      |
| `utils.prompt`              | Prompts user `$1` message and returns true if `YES` or `yes` is input.               |
| `utils.run_installer`       | Downloads and runs web-based shell script installers.                                |
| `utils.version_compare`     | Compare version strings. Usage: `utils.version_compare "$Version1" ">=" "1.2.4"`.    |

#### ellipsis

<h5>ellipsis.each</h5>
Executes command for each installed package.

``` bash
# example (Updates all packages)
ellipsis.each pkg.pull
```
---

<h5>ellipsis.list_packages</h5>
Lists all installed packages.

``` bash
# example (Prints all package names)
for package in ellipsis.list_packages; do
    echo "$package"
done
```
---

#### fs

<h5>fs.backup</h5>
Creates a backup of an existing file, ensuring you don't overwrite existing
backups.

``` bash
# example (Makes a backup of 'file')
fs.backup file
```
---

<h5>fs.file_exists</h5>
Returns true if file exists.

``` bash
# example (Echo message if 'file' exists)

if fs.file_exists file; then
    echo "The file 'file' exists"
fi
```
---

<h5>fs.folder_empty</h5>
Returns true if folder is empty.

``` bash
# example (Echo message if 'folder' is empty)

if fs.folder_empty folder; then
    echo "The folder 'folder' is empty"
fi
```
---


<h5>fs.is_broken_symlink</h5>
Returns true if file is a broken symlink.

``` bash
# example (Echo message if 'broken' is a broken symlink)

if fs.is_broken_symlink broken; then
    echo "The link 'broken' is a broken symlink"
fi
```
---

<h5>fs.is_ellipsis_symlink</h5>
Returns true if file is a symlink pointing to an ellipsis package.

``` bash
# example (Echo message if 'link' links to ellipsis package)
if fs.is_ellipsis_symlink link; then
    echo "'link' is part of an ellipsis package"
fi
```
---

<h5>fs.is_symlink</h5>
Returns true if file is a symlink.

``` bash
# example (Echo message if 'link' is a symlink)
if fs.is_symlink link; then
    echo "'link' is a symlink"
fi
```
---

<h5>fs.link_rfile</h5>
Symlinks a single file.

By default the file will be symlinked into `$ELLIPSIS_HOME`, but another location can be
provided as a second parameter (including filename).

A backup will be made if the destination exists.

``` bash
# example (Links 'file' to 'file' in $ELLIPSIS_HOME)
fs.link_rfile file

# example (Links 'file' to 'other_file' in $HOME)
fs.link_rfile file $HOME/other_file
```
---

<h5>fs.link_file</h5>
Symlinks a single file and prepends a dot if needed.

By default the file will be symlinked into `$ELLIPSIS_HOME`, but another location can be
provided as a second parameter (including filename). If you provide a destination there won't be a
dot prepended.

A backup will be made if the destination exists.

``` bash
# example (Links 'file' to '.file' in $ELLIPSIS_HOME)
fs.link_file file

# example (Links 'file' to '.other_file' in $HOME)
fs.link_file file $HOME/.other_file
```
---

<h5>fs.link_rfiles</h5>
Calls `fs.link_rfile` for all files in a given directory.

The function accepts an optional second parameter to link to another directory
then `$ELLIPSIS_HOME`.

``` bash
# example (Links all files in 'dir' to $ELLIPSIS_HOME)
fs.link_files dir

# example (Links all files in 'dir' to $HOME/.config)
fs.link_files dir $HOME/.config
```
---

<h5>fs.link_files</h5>
Calls `fs.link_file` for all files in a given directory.

The function accepts an optional second parameter to link to another directory
then `$ELLIPSIS_HOME`.

``` bash
# example (Links all files in 'dir' to $ELLIPSIS_HOME, prepended with a dot)
fs.link_files dir

# example (Links all files in 'dir' to $HOME/.config, prepended with a dot)
fs.link_files dir $HOME/.config
```
---

<h5>fs.list_dirs</h5>
Lists directories, useful for passing subdirectories to `fs.link_files`.

``` bash
# example ()
TODO
```
---

<h5>fs.list_symlinks</h5>
Lists symlinks in a folder, defaulting to `$ELLIPSIS_HOME`.

``` bash
# example ()
TODO
```
---

<h5>fs.strip_dot</h5>
Removes `.` prefix from files in a given directory.

``` bash
# example ()
TODO
```
---

<h5>fs.source_first</h5>
Sources the first found file in a list. The sourced file will be echoed. If no
file found return code will be 1.

``` bash
fs.source_first 'file1' '/tmp/file2' "$HOME/file3" || echo "No file found"
```
---

#### git
<h5>git.ahead</h5>
Prints how far ahead a package is from origin.

``` bash
# example ()
TODO
```
---

<h5>git.behind</h5>
Prints how far behead a package is from origin.

``` bash
# example ()
TODO
```
---

<h5>git.clone</h5>
Clones a Git repo, identical to `git clone`.

``` bash
# example ()
TODO
```
---

<h5>git.diffstat</h5>
Displays `git diff --stat`.

``` bash
# example ()
TODO
```
---

<h5>git.status</h5>
Displays `git status -s`.

``` bash
# example ()
TODO
```
---

<h5>git.has_changes</h5>
Returns true if repository has changes.

``` bash
# example ()
TODO
```
---

<h5>git.has_untracked</h5>
Returns true if repository has untracked files.

``` bash
# example ()
TODO
```
---

<h5>git.is_behind</h5>
Returns true if local is behind remote.

``` bash
# example ()
TODO
```
---

<h5>git.last_updated</h5>
Prints commit's relative last update time.

``` bash
# example ()
TODO
```
---

<h5>git.pull</h5>
Identical to `git pull`.

``` bash
# example ()
TODO
```
---

<h5>git.push</h5>
Identical to `git push`.

``` bash
# example ()
TODO
```
---

<h5>git.remote_branch</h5>
Prints name of remote branch.

``` bash
# example ()

```
---

<h5>git.sha1</h5>
Prints last commit's sha1 using `git rev-parse --short HEAD`.

``` bash
# example ()
TODO
```
---

#### os

<h5>os.platform</h5>
Returns one of `cygwin`, `freebsd`, `linux`, `osx`.

``` bash
# example ()
TODO
```
---

#### path

<h5>path.abs_path</h5>
Return absolute path to `$1`.

``` bash
# example ()
TODO
```
---

<h5>path.is_path</h5>
Simple heuristic to determine if `$1` is a path.

``` bash
# example ()
TODO
```
---

<h5>path.relative_to_home</h5>
Replaces `$HOME` with `~`

``` bash
# example ()
TODO
```
---

<h5>path.expand</h5>
Replaces `~` with `$HOME`

``` bash
# example ()
TODO
```
---

<h5>path.relative_to_packages</h5>
Strips `$ELLIPSIS_PACKAGES` from path.

``` bash
# example ()
TODO
```
---

<h5>path.strip_dot</h5>
Strip dot from hidden files/folders.

``` bash
# example ()
TODO
```
---

#### Utils

<h5>utils.cmd_exists</h5>
Returns true if command exists.

``` bash
# example ()
TODO
```
---

<h5>utils.is_interactive</h5>
Returns true if ellipsis is running in an interactive terminal.

``` bash
# example ()
TODO
```
---

<h5>utils.prompt</h5>
Prompts user `$1` message and returns true if `YES` or `yes` is input.

A default answer can be provided as a second argument. If there is no
controlling terminal, this will be used instead of asking for input.

``` bash
# example ()
TODO
```
---

<h5>utils.run_installer</h5>
Downloads and runs web-based shell script installers.

``` bash
# example ()
TODO
```
---

<h5>utils.version_compare</h5>
Compare version strings. Usage: `utils.version_compare "$Version1" ">="
"1.2.4"`.

``` bash
# example ()
TODO
```
---
