import os, boto3, json
import urllib.request, urllib.parse
from urllib.error import HTTPError
import logging

from botocore.exceptions import ClientError

client = boto3.client('ecr')
logger = logging.getLogger()


def get_all_image_data(repository):
    """
    Gets a list of dicts with Image tags and latest scan results.

    :param repository:
    :return: [{'imageTags': ['1.0.70'], 'imageScanStatus': {'HIGH': 21, 'MEDIUM': 127, 'INFORMATIONAL': 115, }}]
    """
    images = []
    levels = os.environ['RISK_LEVELS']

    try:
        response = client.describe_images(repositoryName=repository, filter={
            'tagStatus': 'TAGGED'
        })['imageDetails']
    except ClientError as c:
        logger.error("Failed to get result from describe images with, client error: {}".format(c))
        return []

    for image in response:
        image_data = {}
        try:
            image_data['imageTags'] = image['imageTags']
        except KeyError:
            image_data['imageTags'] = 'IMAGE UNTAGGED'
        try:
            image_data['imageScanStatus'] = image['imageScanFindingsSummary']['findingSeverityCounts']
        except KeyError:
            logger.error('FAILED TO RETRIEVE LATEST SCAN STATUS for image {}'.format(image_data['imageTags']))
            continue

        if len(levels) > 0:
            image_data['imageScanStatus'] = {key: value for key, value in image_data['imageScanStatus'].items() if key in levels}

        if len(image_data['imageScanStatus']) > 0:
            images.append(image_data)

    return images


def get_all_repositories():
    """
    Gets a list of ECR repository string names.
    :return: ['repository1', 'repository2', 'repository3']
    """
    repositories = []
    response = client.describe_repositories()['repositories']
    for repository in response:
        repositories.append(repository['repositoryName'])
    return repositories


def get_scan_results():
    repositories = get_all_repositories()
    all_images = {}
    for repository in repositories:
        all_images[repository] = get_all_image_data(repository)
    return all_images


def convert_scan_dict_to_string(scan_dict):
    """
    converts parsed ImageScanStatus dictionary to string.
    :param scan_dict:  {'HIGH': 64, 'MEDIUM': 269, 'INFORMATIONAL': 157, 'LOW': 127, 'CRITICAL': 17, 'UNDEFINED': 6}
    :return: HIGH 64, MEDIUM 269, INFORMATIONAL 157, LOW 127, CRITICAL 17, UNDEFINED 6
    """
    result = ''

    if not scan_dict:
        return result
    try:
        for key, value in scan_dict.items():
            result = result + key + " " + str(value) + ", "
    except AttributeError:
        return "Failed to retrieve repository scan results"

    return result[:len(result)-2]


def convert_image_scan_status(repository_scan_results):
    repository_scan_block_list = []
    for image in sorted(repository_scan_results, key=lambda imageScanResult: imageScanResult['imageTags'][0],
                        reverse=True):
        image_block = dict()
        image_block["image"] = image['imageTags'][0]
        image_block["vulnerabilities"] = convert_scan_dict_to_string((image['imageScanStatus']))
        repository_scan_block_list.append(image_block)
    return repository_scan_block_list


def create_image_scan_slack_block(repository, repository_scan_block_list):

    blocks = []

    # Generate slack messages for image scan results.
    for image in repository_scan_block_list:
        blocks.append(
            {
                "type": "section",
                "text": {
                    "type": "mrkdwn",
                    "text": "*`{}:{}`* vulnerabilities: {}".format(repository, image['image'], image['vulnerabilities'])
                }
            }
        )
    return blocks


# Send a message to a slack channel
def notify_slack(slack_block):
    slack_url = os.environ['SLACK_WEBHOOK_URL']
    slack_channel = os.environ['SLACK_CHANNEL']
    slack_username = os.environ['SLACK_USERNAME']
    slack_emoji = os.environ['SLACK_EMOJI']

    payload = {
        "channel": slack_channel,
        "username": slack_username,
        "icon_emoji": slack_emoji,
        "blocks": slack_block
    }

    data = urllib.parse.urlencode({"payload": json.dumps(payload)}).encode("utf-8")
    req = urllib.request.Request(slack_url)

    try:
        result = urllib.request.urlopen(req, data)
        return json.dumps({"code": result.getcode(), "info": result.info().as_string()})

    except HTTPError as e:
        logging.error("{}: result".format(e))
        return json.dumps({"code": e.getcode(), "info": e.info().as_string()})


def lambda_handler(event, context):

    scan_results = get_scan_results()

    for repository, values in scan_results.items():
        if len(values) > 0:
            repository_scan_results = convert_image_scan_status(values)
            slack_block = create_image_scan_slack_block(repository, repository_scan_results)
        else:
            continue

        if len(slack_block) > 0:
            try:
                response = notify_slack(slack_block=slack_block)
                if json.loads(response)["code"] != 200:
                    logger.error("Error: received status {} for slack_block {}".format(json.loads(response)["info"], slack_block))
            except Exception as e:
                logger.error(msg=e)
