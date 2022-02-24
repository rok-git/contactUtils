// Compile:
//      cc -framework Foundation -framework Contacts -fobjc-arc name2tel.m -o name2tel
#import <Contacts/Contacts.h>
#include <unistd.h>

#define DONT_SHOW_STDERR

void usage(char * me)
{
    printf("Usage: %s [-i] name\n", me);
    exit(1);
}


int main(int argc, char *argv[])
{
    @autoreleasepool{
        NSString *name;
        BOOL useID = NO, showNote = NO, idSearch = NO;
        char sw;
        char *me = argv[0];
        while((sw = getopt(argc, argv, "inI")) != -1){
            switch(sw){
                case 'i':
                    // Show the identifier.  The identifier can be used 
                    // to open AddressBook.app (Contacts.app) as 
                    // "open addressbook://itendifier"
                    useID = YES;
                    break;
                case 'I':
                    // search identifier
                    idSearch = YES;
                    break;
                case 'n':
                    // Show the note.
                    showNote = YES;
                    break;
            }
        }
        argc -= optind;
        argv += optind;
        if(argc != 0)
            name = [NSString stringWithUTF8String: argv[0]];
        else
            usage(me);

        if([CNContactStore authorizationStatusForEntityType: CNEntityTypeContacts] != CNAuthorizationStatusAuthorized){
            NSLog(@"%@", @"no authorization");
        }

#ifdef DONT_SHOW_STDERR
        // something send err message to stderr, so ignore it...
        int fdx = dup(STDERR_FILENO);
        close(STDERR_FILENO);
        int fd = open("/dev/null", O_WRONLY);
        dup2(fd, STDERR_FILENO);
#endif

        CNContactStore *store = [[CNContactStore alloc] init];
        NSPredicate *predicate;
        if(idSearch){
            predicate = [CNContact predicateForContactsWithIdentifiers: @[name.stringByRemovingPercentEncoding]];
        }else{
            predicate = [CNContact predicateForContactsMatchingName: name];
        }
        NSError *err;
        NSArray *keys = @[CNContactPhoneNumbersKey, CNContactGivenNameKey, CNContactFamilyNameKey, CNContactOrganizationNameKey, CNContactIdentifierKey, CNContactNoteKey];
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
            if(useID){
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
            if(showNote && ([contact.note length])){
                NSString *note = [contact.note stringByReplacingOccurrencesOfString: @"\n" withString: @"\n        "];
                [stdOut writeData: [[NSString stringWithFormat: @"    Note:\n        %@\n", note] dataUsingEncoding: NSUTF8StringEncoding] error: &err];
            }
        }
        return 0;
    }
}
