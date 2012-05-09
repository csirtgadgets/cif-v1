package CIF::Message;

use strict;
use warnings;

## TODO clean this up and .proto it
our $VERSION = '0.99_02';
$VERSION = eval $VERSION;

use Google::ProtocolBuffers;

Google::ProtocolBuffers->parse('
    message MessageType {
        enum StatusType {
            SUCCESS         = 1;
            FAILED          = 2;
            UNAUTHORIZED    = 3;
        }
        enum MsgType {
            QUERY       = 1;
            SUBMISSION  = 2;
            REPLY       = 3;
        }
        enum RestrictionType {
            restriction_type_default        = 1;
            restriction_type_need_to_know   = 2;
            restriction_type_private        = 3;
            restriction_type_public         = 4;
        }
        message MapType {
            required string key = 1;
            required string value = 2;
        }
        message QueryType {
            optional string apikey      = 1;
            optional string guid        = 2;
            optional int32 limit        = 3;
            optional int32 confidence   = 4;
            optional bool nolog         = 5;
            required string query       = 6;
            optional string description = 7;
        }
        message FeedType {
            required string description             = 1;
            required string updated                 = 2;
            optional RestrictionType restriction    = 3;
            repeated MapType restriction_map        = 4;
            repeated MapType group_map              = 5;
            repeated bytes entry                    = 6;
            optional string guid                    = 7;
            optional int32 confidence               = 8;
        }
        message SubmissionType {
            optional string apikey      = 1;
            optional string guid        = 2;
            repeated byptes data        = 3;
        }
        message ReplyType {
            repeated FeedType feed = 1; 
        }    
        required float version      = 1;
        required MsgType type       = 2;
        optional StatusType status  = 3;
        repeated bytes data         = 4;
    }
    ', { create_accessors   => 1, follow_best_practice => 1 }
);

1;