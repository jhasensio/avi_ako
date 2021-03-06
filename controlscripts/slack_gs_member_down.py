#!/usr/bin/python
import requests
import os
import sys
import json
requests.packages.urllib3.disable_warnings()


def parse_avi_params(argv):
    if len(argv) != 2:
        return {}
    script_parms = json.loads(argv[1])
    return script_parms

# Script entry
if __name__ == "__main__":
  script_parms = parse_avi_params(sys.argv)

 
  obj_uuid=script_parms['events'][0]['obj_uuid']
  obj_name=script_parms['events'][0]['obj_name']
  gs_member_ip_add=script_parms['events'][0]['event_details']['se_hm_gsgroup_details']['gsmember']['ip']['addr']
  gslb_service=script_parms['events'][0]['event_details']['se_hm_gsgroup_details']['gslb_service']
  gs_group=script_parms['events'][0]['event_details']['se_hm_gsgroup_details']['gsgroup']
  message=("GS_MEMBER_DOWN: The service "+obj_uuid+" that is a member of the GSLB Pool *"+obj_name+"* at the IP *"+gs_member_ip_add+"* is no longer available for the GSLB service "+gslb_service+".")
  message_slack={
                 "text": "Alarm message from AVI NSX ALB",
                 "color": "#FF0000", 
                 "fields": [{
                 "title": "GS_MEMBER_DOWN",
                 "value": "The service "+obj_uuid+" that is a member of the GSLB Pool *"+obj_name+"* at the IP *"+gs_member_ip_add+"* is no longer available for the GSLB service "+gslb_service+"."
                }]}
  
  print(message)


# Set the webhook_url to the one provided by Slack when you create the webhook at https://my.slack.com/services/new/incoming-webhook/
  webhook_url = 'https://hooks.slack.com/services/<use-your-webhook-here>'

  response = requests.post(
     webhook_url, data=json.dumps(message_slack),
     headers={'Content-Type': 'application/json'}
 )
  if response.status_code != 200:
    raise ValueError(
        'Request to slack returned an error %s, the response is:\n%s'
        % (response.status_code, response.text)
    )
