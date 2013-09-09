1. Goals
==
The CIF protocol is a simple encapsulation protocol for querying data resources.

* Proivde a standard protocol for access control and API keys
* Provide simple query/submission encapsulation communications

2. License
==

This Specification is free software; you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation; either version 3 of the License, or (at your option) any later version.

This Specification is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public License along with this program; if not, see <http://www.gnu.org/licenses>.

3. Change Process
==
This document is governed by the [Consensus-Oriented Specification System (COSS)](http://www.digistan.org/spec:1/COSS).


4. Lanugage
==
The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this document are to be interpreted as described in RFC [2119](http://www.ietf.org/rfc/rfc2119.txt).

5. Protocol
==
## 5.1 Message
```
+----------------+
| Message        |
+----------------+
| ENUM status    |<>--{0..*}[ Query      ]
| STRING version |<>--{0..*}[ Submission ]
| ENUM type      |
| STRING apikey  |
| BYTES data     |
+----------------+
```

## Query
Zero or many.

## Submission
Required. String. A free-form string representing the persons name.

#### status
Optional. Enum. Status reply for the request.

#### version
Required. String. Version string of the protocol.

#### type
Required. Enum. The message type.

#### apikey
Optional. String. The API key value.

#### data
One or more. Bytes. The message payload.

## 5.2 Query
```
+--------------------+
| Query              |
+--------------------+
| STRING apikey      |<>--{1..*}[ QueryStruct ]
| STRING guid        |
| INT32 limit        |
| INT32 confidence   |
| STRING description |
| BOOL feed          | 
+--------------------+
```

## QueryStruct
Required. String. A free-form string representing the perons phone number.

#### apikey
Optional. String. The apikey string.

#### guid
Optional. String. The group id string.

#### limit
Optional. Int32. Limit value for the query (max results to return).

#### confidence
Optional. Int32. Confidence value for the query. 

#### description
Optional. String. How to describe the query, used for logging the query.

#### feed
Optional. Bool. Depicts if the query is a feed query or a normal query.

## 5.3 Submission
```
+-------------------+
| Submission        |
+-------------------+
| STRING guid       |<>--{1..*}[ Feed ]
+-------------------+
```

## Feed
One or more. Encasulates data to be submitted.

#### guid
Optional. String. Defines what group id the data should be submitted under for the purposes of access control.

## 5.4 Feed
```
+--------------------+
| Feed               |
+--------------------+
| STRING version     |<>--{0..1}[ restriction     ]
| STRING guid        |<>--{0..*}[ restriction_map ]
| INT32 confidence   |<>--{0..*}[ group_map       ]
| STRING description |<>--{0..*}[ feeds_map       ]
| STRING ReportTime  |<>--{1..*}[ data            ]
| STRING uuid        |
| INT32 query_limit  |
+--------------------+
```

## restriction
Zero or One.

## restriction_map
Zero or Many.

## group_map
Zero or many.

## feeds_map
Zero or many.

## data
One or many.

#### version
Required. String.

#### guid
Optional. String.

#### confidence
Optional. Int32.

#### description
Required. String.

#### ReportTime
Required. String.

#### query_limit
Optional. Int32.


6. Data Types
==


7. Reference Implementations
==
1. Google Protocol Buffers Developer Guide - [developers.google.com](https://developers.google.com/protocol-buffers/docs/overview)

8. References
==

9. Bibliography
==
1. "Key words for use in RFCs to Indicate Requirement Levels" - [ietf.org](http://tools.ietf.org/html/rfc2119)
