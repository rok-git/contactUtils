// Compile:
//      cc -framework Foundation -framework Contacts -fobjc-arc cn2vcf.m -o cn2vcf
#import <Contacts/Contacts.h>
#include <unistd.h>
#include <libgen.h>

#define DONT_SHOW_STDERR

void usage(char * me)
{
    printf("Usage: %s -I id > data.vcf\n", me);
    printf("       %s name > data.vcf\n", me);
    printf("       %s -a > data.vcf\n", me);
    exit(1);
}


int main(int argc, char *argv[])
{
    @autoreleasepool{
        NSString *name;
        char *me = argv[0];
        BOOL idSearch = NO, showAll = NO;
        char sw;
        while((sw = getopt(argc, argv, "aI")) != -1){
            switch(sw){
                case 'a':
                    showAll = YES;
                    break;
                case 'I':
                    // search identifier
                    idSearch = YES;
                    break;
            }
        }
        argc -= optind;
        argv += optind;
        if(!showAll){
            if(argc != 0)
                name = [NSString stringWithUTF8String: argv[0]];
            else
                usage(basename(me));
        }else{  // all contacts
            if((argc != 0) || (idSearch)){
                printf("'-a' cannot be used with other options nor arguments.\n");
                return 1;
            }
        }

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

        NSError *err = nil;
        NSArray *contacts;
        NSArray *keys = @[[CNContactVCardSerialization descriptorForRequiredKeys]];
        CNContactStore *store = [[CNContactStore alloc] init];
        if(!showAll){
            NSPredicate *predicate;
            if(idSearch)
                predicate = [CNContact predicateForContactsWithIdentifiers: @[name.stringByRemovingPercentEncoding]];
            else
                predicate = [CNContact predicateForContactsMatchingName: name];
            contacts = [store unifiedContactsMatchingPredicate: predicate keysToFetch: keys error: &err];
            if(err)
                return 1;
        }else{ // show all
            CNContactFetchRequest *request = [[CNContactFetchRequest alloc] initWithKeysToFetch: keys];
            __block NSMutableArray *allContacts = [@[] mutableCopy];
            BOOL success = [store enumerateContactsWithFetchRequest: request
                error: &err
                usingBlock: ^(CNContact * _Nonnull contact, BOOL * _Nonnull stop){
                    [allContacts addObject: contact];
                }
            ];
            if(err)
                return 1;
            contacts = [allContacts copy];
        }

#ifdef DONT_SHOW_STDERR
        dup2(fdx, STDERR_FILENO);
        close(fd);
#endif 

        NSFileHandle *stdOut = [NSFileHandle fileHandleWithStandardOutput];
        NSData *vcfData = [CNContactVCardSerialization dataWithContacts: contacts error: &err];
        [stdOut writeData: vcfData error: &err];
        return 0;
    }
}
