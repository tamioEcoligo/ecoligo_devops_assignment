import asyncio
import json
import logging
import time

async def read_questions_async():
    with open('../data/questions.json') as stream:
        questions = json.load(stream)

    for question in questions:
        logging.info(question)
    return None

if __name__ == "__main__":
    logging.info("--------- Start running cronjob ---------")
    start = time.time()
    asyncio.run(read_questions_async())
    logging.info(f"--------- Finished running cronjob {time.time() - start} seconds ---------")
