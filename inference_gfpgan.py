import boto3
import cv2
import glob
import numpy as np
import os
import json
import requests
import logging
import time
import uuid

from pythonjsonlogger import jsonlogger
from basicsr.utils import imwrite
from pathlib import Path
from gfpgan import GFPGANer

sqs = boto3.resource("sqs")
queue = sqs.get_queue_by_name(QueueName=os.environ["SQS_QUEUE_NAME"])
dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.environ["DYNAMODB_TABLE_NAME"])
s3 = boto3.client("s3")

for name in ["boto", "urllib3", "s3transfer", "boto3", "botocore", "nose"]:
    logging.getLogger(name).setLevel(logging.CRITICAL)

def setup_logging(log_level):
    logger = logging.getLogger()

    logger.setLevel(log_level)
    json_handler = logging.StreamHandler()
    formatter = jsonlogger.JsonFormatter(
        fmt="%(asctime)s %(levelname)s %(name)s %(message)s"
    )
    json_handler.setFormatter(formatter)
    logger.addHandler(json_handler)

def main(logger, message):
    [f.unlink() for f in Path("./inputs").glob("*") if f.is_file()]
    [f.unlink() for f in Path("./results").glob("*") if f.is_file()]

    model_path = "experiments/pretrained_models/GFPGANv1.4.pth"
    upscale = 2
    arch = "clean"
    channel = 2
    ext = "auto"
    suffix = None
    save_root = "results"
    os.makedirs(save_root, exist_ok=True)

    inputs_path = os.path.join("inputs", "input.jpg")

    img_data = requests.get(url=message["imageUrl"]).content

    logger.info(f"Downloading image {message['imageUrl']} to {inputs_path}")

    try:
        with open(inputs_path, "wb") as handler:
            handler.write(img_data)
    except:
        logger.error('Cannot download file')
        return

    restorer = GFPGANer(
        model_path=model_path,
        upscale=upscale,
        arch=arch,
        channel_multiplier=channel,
        bg_upsampler=None,
    )

    img_list = sorted(glob.glob(os.path.join("inputs", "*")))
    for img_path in img_list:
        # read image
        img_name = os.path.basename(img_path)
        logger.info(f"Processing {img_name} ...")
        basename, ext = os.path.splitext(img_name)
        input_img = cv2.imread(img_path, cv2.IMREAD_COLOR)

        # restore faces and background if necessary
        cropped_faces, restored_faces, restored_img = restorer.enhance(
            input_img, has_aligned=False, only_center_face=True, paste_back=True
        )

        # save faces
        for idx, (cropped_face, restored_face) in enumerate(
            zip(cropped_faces, restored_faces)
        ):
            # save cropped face
            save_crop_path = os.path.join(
                save_root, "cropped_faces", f"{basename}_{idx:02d}.png"
            )
            imwrite(cropped_face, save_crop_path)
            # save restored face
            if suffix is not None:
                save_face_name = f"{basename}_{idx:02d}_{suffix}.png"
            else:
                save_face_name = f"{basename}_{idx:02d}.png"
            save_restore_path = os.path.join(
                save_root, "restored_faces", save_face_name
            )
            imwrite(restored_face, save_restore_path)
            # save comparison image
            cmp_img = np.concatenate((cropped_face, restored_face), axis=1)
            imwrite(
                cmp_img, os.path.join(save_root, "cmp", f"{basename}_{idx:02d}.png")
            )

        if restored_img is not None:
            if ext == "auto":
                extension = ext[1:]
            else:
                extension = ext

            if suffix is not None:
                save_restore_path = os.path.join(
                    save_root, "restored_imgs", f"{basename}_{suffix}.{extension}"
                )
            else:
                save_restore_path = os.path.join(
                    save_root, "restored_imgs", f"{basename}.{extension}"
                )

            logger.info(f"Saving restored image to {save_restore_path} ...")

            imwrite(restored_img, save_restore_path)

    s3key = f'gfpgan_{message["orgId"]}_{uuid.uuid4().hex}.jpg'
    s3.upload_file(
        "results/restored_imgs/input..jpg", os.environ["S3_BUCKET_NAME"], s3key
    )
    new_record = message.copy()
    new_record["enhancedImageS3Key"] = s3key
    new_record["updatedAt"] = round(time.time())
    new_record["timeTaken"] = new_record["updatedAt"] - new_record["createdAt"]
    update_record(new_record)
    logger.info(f"Result uploaded in S3: {s3key}")


def create_record(message):
    response = table.put_item(
        Item={
            "enhancementId": message["enhancementId"],
            "imageUrl": message["imageUrl"],
            "createdAt": message["createdAt"],
        }
    )
    return response


def update_record(message):
    response = table.put_item(
        Item={
            "enhancementId": message["enhancementId"],
            "imageUrl": message["imageUrl"],
            "createdAt": message["createdAt"],
            # Additional Props
            "enhancedImageS3Key": message["enhancedImageS3Key"],
            "updatedAt": message["updatedAt"],
            "timeTaken": message["timeTaken"],
        }
    )
    return response

def retrieve_messages():
    setup_logging(logging.INFO)
    logger = logging.getLogger()
    logger.info("Starting retrieve_messages")
    while True:
        logger.debug("Fetching SQS messages")
        messages = queue.receive_messages(MaxNumberOfMessages=1, WaitTimeSeconds=1)
        for message in messages:
            parsed_message = json.loads(message.body)
            parsed_message["createdAt"] = round(time.time())
            logger.info(parsed_message)
            create_record(parsed_message)
            main(logger, parsed_message)
            message.delete()
        time.sleep(5)


if __name__ == "__main__":
    retrieve_messages()
