# contactUtils for macOS   

## What?

contactUtils contains some programs to retrieve information using macOS's Contacts Frameworks.

- `cnfind`
- `cn2vcf`
- `tel2name`

`cnfind` is a program to find some information using name, nickname, note etc as a search key.

`cn2vcf` makes a vcf from contacts' information.

`tel2name` searches for contacts by a phone number.  Apple's Contacts.app cannot use a phone number as a key to search.

## How?

### How to commpile:

Just type `make` in tha directory that is containing source code.  If you want to install in /usr/local, type `sudo make install`.  Of course you need Command Line Tools for Xcode.

### How to use:

To search for telephone numbers, just use `cnfind name`.  Name can be matched with the first name, the last name, the organization name, the nickname and so on.

>`cnfind [-I|-M] [-a] [-i] [-m] [-n] name`

For example, `cnfind John` returns John's name, organaization and phone numbers.

'-I' or '-M' option makes it possible to search for contacts by an identifier or an email address as a search key (an identifier or an email address must match exactly.).

'-a', '-i', '-m' and '-n' specify to show postal addresses, IDs, email address(es) and notes respectively.  You can use the ID as a search key with a '-I' option and also you may open Contacts.app by "open addressbook://ID"

The '-n' option is very slow because it uses AppleScript to get the notes from Contacts.app.

With `tel2name`, you can search for contacts using a phone number as a search key.  There's no option to show other information than the name and number, you must search by `cnfind` with that name (of course you can use -a, -i, -m and -n along with `cnfind`) to know other information.

Example:
> `tel2name 0XX-XXX-XXXX`

`cn2vcf` outputs retrieved data in VCF format to standard output (so, you may want to redirect to a file).  You can search by name (without options) or by ID (with -I option).  If the result matches more than one contacts, every contacts are included in the VCF data.  If you want all contacts to be included in VCF format, you can use '-a' option.  

Examples:

> `cn2vcf 山田 > /tmp/Yamada.vcf`

> `cn2vcf -a > /tmp/all.vcf`

