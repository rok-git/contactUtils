// Compiile:
//      cc -framework Foundation -framework Contacts -fobjc-arc tel2name.m -o tel2name
#import <Contacts/Contacts.h>
#include <unistd.h>

#define DONT_SHOW_STDERR

void usage(char *me)
{
    printf("Usage: %s phonenumber\n", me);
    exit(1);
}

int main(int argc, char *argv[])
{
    @autoreleasepool{
        NSString *num;
        if(argc != 1){ // only the first argument is used.
            num = [NSString stringWithUTF8String: argv[1]];
            num = [[num componentsSeparatedByCharactersInSet: [NSCharacterSet characterSetWithCharactersInString: @" -()"]] componentsJoinedByString: @""]; 
        }else{
            usage(argv[0]);
        }

        if([CNContactStore authorizationStatusForEntityType: CNEntityTypeContacts] != CNAuthorizationStatusAuthorized){
            NSLog(@"%@", @"no authorization");
            exit(1);
        }

#ifdef DONT_SHOW_STDERR
        // something send err message to stderr, so ignore it...
        int fdx = dup(STDERR_FILENO);
        close(STDERR_FILENO);
        int fd = open("/dev/null", O_WRONLY);
        dup2(fd, STDERR_FILENO);
#endif

        CNContactStore *store = [CNContactStore new];
        NSError *err;
        CNContactFetchRequest *request = [[CNContactFetchRequest alloc] initWithKeysToFetch: @[CNContactGivenNameKey, CNContactFamilyNameKey, CNContactPhoneNumbersKey, CNContactOrganizationNameKey]];
        __block NSMutableArray *allContacts = [@[] mutableCopy];
        BOOL success = [store enumerateContactsWithFetchRequest: request
            error: &err
            usingBlock: ^(CNContact * _Nonnull contact, BOOL * _Nonnull stop){
                [allContacts addObject: contact];
            }
        ];

#ifdef DONT_SHOW_STDERR
        dup2(fdx, STDERR_FILENO);
        close(fd);
#endif 

        if(!success)
            return 2;

        NSFileHandle *stdOut = [NSFileHandle fileHandleWithStandardOutput];
        NSString *fullName;
        for(CNContact *contact in allContacts){
            for(CNLabeledValue *pn in contact.phoneNumbers){
                NSString *phoneNumber = ((CNPhoneNumber *)(pn.value)).stringValue;
                phoneNumber = [[phoneNumber componentsSeparatedByCharactersInSet: [NSCharacterSet characterSetWithCharactersInString: @" -()"]] componentsJoinedByString: @""]; 
                if([phoneNumber containsString: num]){
                    if([contact.organizationName length]){
                        fullName = [NSString stringWithFormat: @"%@ %@ (%@)", contact.familyName, contact.givenName, contact.organizationName];
                    }else{
                        fullName = [NSString stringWithFormat: @"%@ %@", contact.familyName, contact.givenName];
                    }
                    [stdOut writeData: [[NSString stringWithFormat: @"%@: %@\n", fullName, phoneNumber] dataUsingEncoding: NSUTF8StringEncoding] error: &err];
                }
            }
        }
        return 0;
    }
}
