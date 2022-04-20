// Compile:
//      cc -framework Foundation -framework Contacts -fobjc-arc cn2vcf.m -o cn2vcf.m 
#import <Contacts/Contacts.h>
#include <unistd.h>
#include <libgen.h>

#define DONT_SHOW_STDERR

void usage(char * me)
{
    printf("Usage: %s -I id > data.vcf\n", me);
    printf("       %s name > data.vcf\n", me);
    exit(1);
}


int main(int argc, char *argv[])
{
    @autoreleasepool{
        NSString *name;
        BOOL idSearch = NO;
        char *me = argv[0];
        char sw;
        while((sw = getopt(argc, argv, "I")) != -1){
            switch(sw){
                case 'I':
                    // search identifier
                    idSearch = YES;
                    break;
            }
        }
        argc -= optind;
        argv += optind;
        if(argc != 0)
            name = [NSString stringWithUTF8String: argv[0]];
        else
            usage(basename(me));

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
        if(idSearch)
            predicate = [CNContact predicateForContactsWithIdentifiers: @[name.stringByRemovingPercentEncoding]];
        else
            predicate = [CNContact predicateForContactsMatchingName: name];
        NSError *err;
        NSMutableArray *keys = [@[CNContactPhoneNumbersKey, CNContactGivenNameKey, CNContactFamilyNameKey, CNContactOrganizationNameKey] mutableCopy];
        [keys addObject: [CNContactVCardSerialization descriptorForRequiredKeys]];
        NSArray *contacts = [store unifiedContactsMatchingPredicate: predicate keysToFetch: keys error: &err];

#ifdef DONT_SHOW_STDERR
        dup2(fdx, STDERR_FILENO);
        close(fd);
#endif 

        if(err)
            return 1;

        NSFileHandle *stdOut = [NSFileHandle fileHandleWithStandardOutput];
        NSData *vcfData = [CNContactVCardSerialization dataWithContacts: contacts error: &err];
        [stdOut writeData: vcfData error: &err];
        return 0;
    }
}
