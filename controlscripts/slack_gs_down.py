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
  message=("GS_SERVICE_DOWN: The service "+gslb_service+" is no longer available.")
  message_slack={
                 "text": "Alarm Message from AVI NSX ALB",
                 "color": "#FF0000", 
                 "fields": [{
                 "title": "GS_SERVICE_DOWN",
                 "value": "The service "+gslb_service+" is no longer available.",
                }]}
  print(message)

# Set the webhook_url to the one provided by Slack when you create the webhook at https://my.slack.com/services/new/incoming-webhook/
  webhook_url = 'https://hooks.slack.com/services/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'

  response = requests.post(
     webhook_url, data=json.dumps(message_slack),
     headers={'Content-Type': 'application/json'}
 )
  if response.status_code != 200:
    raise ValueError(
        'Request to slack returned an error %s, the response is:\n%s'
        % (response.status_code, response.text)
    )
