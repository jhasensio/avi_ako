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

  gslb_service=script_parms['events'][0]['event_details']['se_hm_gs_details']['gslb_service']
  message=("GS_SERVICE_UP: The service *"+gslb_service+"* is now up and running.")
  message_slack={
                 "text": "Alarm Message from NSX ALB",
                 "color": "#00FF00", 
                 "fields": [{
                 "title": "GS_SERVICE_UP",
                 "value": "The service *"+gslb_service+"* is now up and running."
                }]}
  #print(message)

# Set the webhook_url to the one provided by Slack when you create the webhook at https://my.slack.com/services/new/incoming-webhook/ 

webhook_url = 'https://hooks.slack.com/services/<use-your-webhook-url-here>'
  response = requests.post(
     webhook_url, data=json.dumps(message_slack),
     headers={'Content-Type': 'application/json'}
 )
  if response.status_code != 200:
    raise ValueError(
        'Request to slack returned an error %s, the response is:\n%s'
        % (response.status_code, response.text)
    )
