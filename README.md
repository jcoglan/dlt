# dlt

`dlt` is a prototype archive format and extremely basic version control system.
It stores successive versions of a file using delta compression, with the most
recent version stored verbatim and previous versions stored as a chain of
deltas. The archive maintains some metadata about each version, currently its
original and compressed sizes in bytes, and the time at which it was added.


## Usage

The `dlt` executable supports the following commands:

- `dlt <packfile> --add <path>`: adds the current content of the file at
  `<path>` to the archive at `<packfile>`, appending it to the version history

- `dlt <packfile> --list`: lists the versions stored in the archive, with their
  timestamp and size in bytes

- `dlt <packfile> --export <path> --version <n>`: extracts version `<n>` from
  the archive and writes it to `<path>`; if `<n>` is unspecified it defaults to
  the latest version


## File format

A `dlt` archive consists of all the stored versions written one after another,
from oldest to newest. The newest is stored verbatim while all older versions
are deltas based on the next newer version. After these we store a table of
fixed-size entries describing the versions present in the archive, each entry
containing the version's byte offset within the archive, its original and
compressed sizes, the index of the version it's compressed against, and a
timestamp. The file ends with a file format version number and a count of the
number of versions present.

This format means that adding a new version doesn't need to touch data for any
old versions. When adding a new version, we take the latest version from the
archive, compress it against the new version, then overwrite the latest version
and the index table with the compressed result, the new version, and an updated
table. All older deltas stored at the start of the file are untouched.
