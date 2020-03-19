import boto3
import logging

from botocore.exceptions import ClientError


client = boto3.client('ecr')
logger = logging.getLogger()


def get_all_images(repository):
    """
    Return a list of images for specified repository.
    :param repository:
    :return: ['1.0.1', '1.0.2', '1.0.3']
    """
    images = []
    try:
        response = client.describe_images(repositoryName=repository)['imageDetails']
    except ClientError as c:
        logger.error("Failed to get images for repository {} with error: ".format(repository, c))
        return []
    for image in response:
        images.append(image['imageDigest'])
    return images


def get_all_repositories():
    """
    Returns a list with ECR repository names
    :return: ['repo1', 'repo2', 'repo3']
    """
    repositories = []
    try:
        response = client.describe_repositories()
    except ClientError as c:
        logger.error("Failed to retrieve ECR repositories with the following error: {}: ".format(c))
        return

    try:
        repository_names = response['repositories']
    except KeyError:
        logger.error("Response did not return any repository names")
        return

    for repository in repository_names:
        repositories.append(repository['repositoryName'])
    return repositories


def get_repository_image_dict():
    """
    Returns a dict with repository and a list of images that it has.
    :return: {'repo1': ['1.0.1', '1.0.2', '1.0.3'], 'repo2': ['2.2.1', '2.2.2']}
    """
    repositories = get_all_repositories()
    all_images = {}
    for repository in repositories:
        all_images[repository] = get_all_images(repository)
    return all_images


def run_image_scan(repository, image):
    try:
        client.start_image_scan(repositoryName=repository,imageId={'imageDigest': image})
    except ClientError as c:
        logger.error("Got error: {}, when running image scan on repository: {}, image: {}".format(c, repository, image))


def lambda_handler(event, context):

    repository_image_dict = get_repository_image_dict()

    for repository in repository_image_dict:
        for image in repository_image_dict[repository]:
            run_image_scan(repository, image)

