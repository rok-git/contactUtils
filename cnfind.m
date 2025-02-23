// Compile:
//      cc -framework Foundation -framework Contacts -fobjc-arc cnfind.m -o cnfind
#import <Contacts/Contacts.h>
#include <unistd.h>
#include <libgen.h>

#define DONT_SHOW_STDERR

void usage(char * me)
{
    printf("Usage: %s [-I|-M] [-a] [-i] [-j] [-m] [-n] name\n", me);
    printf("       ('-I' and '-M' cannot be used at the same time)\n");
    exit(1);
}


int main(int argc, char *argv[])
{
    @autoreleasepool{
        NSString *name;
        BOOL jsonOutput = NO, showAddress = NO, showID = NO, showNote = NO, idSearch = NO, emailSearch = NO, showEmail = NO;
        char sw;
        char *me = argv[0];
        while((sw = getopt(argc, argv, "aijnImM")) != -1){
            switch(sw){
                case 'a':
                    showAddress = YES;
                    break;
                case 'i':
                    // Show the identifier.  The identifier can be used 
                    // to open AddressBook.app (Contacts.app) as 
                    // "open addressbook://itendifier"
                    showID = YES;
                    break;
                case 'I':
                    // search by identifier
                    idSearch = YES;
                    break;
                case 'j':
                    // output result in JSON
                    jsonOutput = YES;
                    NSLog(@"JSON is not yet supported.");
                    break;
                case 'n':
                    // Show the note.
                    showNote = YES;
                    break;
                case 'm':
                    // Show email addresses
                    showEmail = YES;
                    break;
                case 'M':
                    // search by email address
                    emailSearch = YES;
                    break;
                default:
                    usage(me);
                    break;
            }
        }
        argc -= optind;
        argv += optind;
        // Only one argument is used.
        if(argc != 0 && !(idSearch && emailSearch))
            name = [NSString stringWithUTF8String: argv[0]];
        else
            usage(basename(me));

        if([CNContactStore authorizationStatusForEntityType: CNEntityTypeContacts] != CNAuthorizationStatusAuthorized){
            NSLog(@"%@", @"no authorization");
        }

#ifdef DONT_SHOW_STDERR
        // something sends an error message to stderr, so ignore it...
        int fdx = dup(STDERR_FILENO);
        close(STDERR_FILENO);
        int fd = open("/dev/null", O_WRONLY);
        dup2(fd, STDERR_FILENO);
#endif

        CNContactStore *store = [[CNContactStore alloc] init];
        NSPredicate *predicate;
        if(idSearch){
            predicate = [CNContact predicateForContactsWithIdentifiers: @[name.stringByRemovingPercentEncoding]];
        }else if(emailSearch){
            predicate = [CNContact predicateForContactsMatchingEmailAddress: name];
        }else{
            predicate = [CNContact predicateForContactsMatchingName: name];
        }
        NSError *err;
        NSMutableArray *keys = [@[CNContactPhoneNumbersKey, CNContactGivenNameKey, CNContactFamilyNameKey, CNContactOrganizationNameKey] mutableCopy];
        if(showAddress)
            [keys addObject: CNContactPostalAddressesKey];
        if(showID)
            [keys addObject: CNContactIdentifierKey];
/*
        if(showNote){
            // This part is no longer needed.
//            [keys addObject: CNContactNoteKey];
            // Using AppleScript to communicate with Contacts.app makes it
            // possible to get note.
            // *** VERY SLOW... ***
            fprintf(stderr, "-n option (show note field) is no logner supported.\n");
        }
*/
        if(showEmail)
            [keys addObject: CNContactEmailAddressesKey];
        NSArray *contacts = [store unifiedContactsMatchingPredicate: predicate keysToFetch: keys error: &err];

#ifdef DONT_SHOW_STDERR
        dup2(fdx, STDERR_FILENO);
        close(fd);
#endif 

        if(err)
            return 1;
        NSFileHandle *stdOut = [NSFileHandle fileHandleWithStandardOutput];
        for(CNContact *contact in contacts){
            NSString *fullName;
            if([contact.organizationName length]){
                fullName = [NSString stringWithFormat: @"%@ %@ (%@)", contact.familyName, contact.givenName, contact.organizationName];
            }else{
                fullName = [NSString stringWithFormat: @"%@ %@", contact.familyName, contact.givenName];
            }
            if(showEmail && [contact.emailAddresses count]){
                NSMutableArray *addresses = [@[] mutableCopy];
                for(CNLabeledValue *em in contact.emailAddresses){
                    [addresses addObject: [NSString stringWithFormat: @"<%@>", (NSString *)(em.value)]];
                }
                fullName = [NSString stringWithFormat: @"%@ %@", fullName, [addresses componentsJoinedByString: @", "]];
            }
            if(showID){
                fullName = [NSString stringWithFormat: @"%@: [%@]: ", fullName, [contact.identifier stringByAddingPercentEncodingWithAllowedCharacters: NSCharacterSet.URLPathAllowedCharacterSet]];
            }else{
                fullName = [fullName stringByAppendingString: @": "];
            }
            [stdOut writeData: [fullName dataUsingEncoding: NSUTF8StringEncoding] error: &err];
            int c = 0;
            for(CNLabeledValue *pn in contact.phoneNumbers){
                if(c > 0)
                    [stdOut writeData: [@", " dataUsingEncoding: NSUTF8StringEncoding] error: &err];
                [stdOut writeData: 
                    [[NSString stringWithFormat: @"%@", ((CNPhoneNumber *)(pn.value)).stringValue] dataUsingEncoding: NSUTF8StringEncoding] error: &err];
                c++;
            }
            [stdOut writeData: [@"\n" dataUsingEncoding: NSUTF8StringEncoding] error: &err];
            if(showAddress && ([contact.postalAddresses count])){
                NSMutableArray *addresses = [@[] mutableCopy];
                for(CNLabeledValue<CNPostalAddress *> *adr in contact.postalAddresses){
                    [stdOut writeData: [@"Address:\n" dataUsingEncoding: NSUTF8StringEncoding]];
                    NSString *adrStr = [NSString stringWithFormat: @"\t%@\n\t%@ %@\n\t%@", adr.value.street, adr.value.city, adr.value.state, adr.value.postalCode];
                    if(adr.value.country)
                        adrStr = [NSString stringWithFormat: @"%@ %@", adrStr, adr.value.country];
                    [stdOut writeData: [adrStr dataUsingEncoding: NSUTF8StringEncoding] error: &err];
                    [stdOut writeData: [@"\n" dataUsingEncoding: NSUTF8StringEncoding] error: &err];
                }
            }
/*
            if(showNote && ([contact.note length])){
                NSString *note = [contact.note stringByReplacingOccurrencesOfString: @"\n" withString: @"\n        "];
                [stdOut writeData: [[NSString stringWithFormat: @"Note:\t\n        %@\n", note] dataUsingEncoding: NSUTF8StringEncoding] error: &err];
            }
*/
            if(showNote){
                NSString *idString = contact.identifier;
                NSString *scriptTmpl = @"tell application \"Contacts\"\n"
                   "    set p to item 1 of (every person whose id = \"%@\")\n"
                   "    get note of p\n"
                   "end tell";
                NSString *script = [NSString stringWithFormat:scriptTmpl,idString];
                NSAppleScript *applescript = [[NSAppleScript alloc] initWithSource: script];
                if(!applescript){
                    return 1;
                }
                NSDictionary *noteErr = nil;
                NSAppleEventDescriptor * result = [applescript executeAndReturnError: &noteErr];
                if(!noteErr)
                    [stdOut writeData: [[NSString stringWithFormat: @"Note:\t\n\t%@\n", [result stringValue]] dataUsingEncoding: NSUTF8StringEncoding] error: &err];
            }
        }
        return 0;
    }
}
