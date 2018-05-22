alias list-consumer-groups='curl -s localhost:8001/consumers|jq -r ".data[] | [.id, .username] | @tsv" | while read -e id name; do printf "%-40s %-45s " $id $name ; curl -s localhost:8001/consumers/$id/acls|jq -r ".data[] | .group"|paste -s -d" "; done'

alias list-consumer-keys='curl -s localhost:8001/consumers|jq -r ".data[] | [.id, .username] | @tsv" | while read -e id name; do printf "%-40s %-45s " $id $name ; curl -s localhost:8001/consumers/$id/key-auth|jq -r ".data[] | .key "|paste -s -d" ";done'

# return comma separated fields of the json object
curl -s http://some_url_returning_json_object | jq -r '[.id, .enrolledFullTime] | @csv' 

# list of objects in the `data` field
# remove objects with refresh_token==null
# count how many tokens each authenticated_userid has
# and return comma separated: userid,count
curl -s "http://localhost:8001/oauth2_tokens?credential_id=ID&expires_in=1010&size=45000" | jq -r '[.data | del(.[] | select(.refresh_token == null)) | .[] | {user: .authenticated_userid, refresh_token}] | group_by(.user) | map({user: .[0].user, Count: length}) | (.[0] | keys_unsorted) as $keys | $keys, map([.[ $keys[] ]])[] | @csv' > tokens_per_user.txt 

# Run through all records and send the report
#!/bin/bash
MAIL_TO=report-users-list@list.comp.com

ID=$(curl -s localhost:8001/oauth2?client_id=auckland-transport | jq -r '.data[0].id')
curl -s "http://localhost:8001/oauth2_tokens?credential_id=$ID&size=50000" | jq -r '[ .data[] | select(.refresh_token != null) | .authenticated_userid ] | unique | .[]' |\
while read NAME
do
  export NAME && curl -s -H "REMOTE_USER:$NAME" HOST:8061/student/self | jq -r ' {upi: env.NAME, id: .id, re:.enrolledFullTime}'
  usleep 20
done | jq -s -r '. | group_by(.re) | map( [if .[0].re == true then "Eligible" else "Non-eligible" end, length]) |.[] | @tsv ' |\
awk 'BEGIN {ne=0;el=0} /^N/ {ne=$2;next} /^E/ {el=$2;next} END {print "Hello\n"; printf "%d/%d\n\n",el,ne; print "Bye\n"}' |\
mailx -s 'weekly report' -r 'no-reply@list.comp.com' $MAIL_TO
