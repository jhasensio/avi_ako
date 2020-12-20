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
  
  message=("GS_MEMBER_UP: The service "+obj_uuid+" at the IP Address *"+gs_member_ip_add+"* is now up and running for the GSLB service *"+gslb_service+"* as a member of the GSLB pool "+gs_group+".")
  message_slack={
                 "text": "Alarm Message from AVI NSX ALB",
                 "color": "#00FF00", 
                 "fields": [{
                 "title": "GS_MEMBER_UP",
                 "value": "The service "+obj_uuid+" at the IP Address *"+gs_member_ip_add+"* is now up and running for the GSLB service *"+gslb_service+"* as a member of the GSLB pool "+gs_group+"."
                }]}
  print(message)


# Set the webhook_url to the one provided by Slack when you create the webhook at https://my.slack.com/services/new/incoming-webhook/
  webhook_url = 'https://hooks.slack.com/services/<use-your-own-webhook-here>'

  response = requests.post(
     webhook_url, data=json.dumps(message_slack),
     headers={'Content-Type': 'application/json'}
 )
  if response.status_code != 200:
    raise ValueError(
        'Request to slack returned an error %s, the response is:\n%s'
        % (response.status_code, response.text)
    )
