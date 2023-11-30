import requests
from datetime import datetime, timedelta
import boto3
import os

client = boto3.client('s3')

def generate_date_range(start_date:str, end_date:str) -> list:
    # Convert input strings to datetime objects
    start_date = datetime.strptime(start_date, "%Y-%m-%d")
    end_date = datetime.strptime(end_date, "%Y-%m-%d")

    # Calculate the difference between end_date and start_date
    delta = end_date - start_date

    # Generate a list of dates in the range
    date_range = [(start_date + timedelta(days=i)).strftime("%Y-%m-%d") for i in range(delta.days + 1)]

    print(date_range)

    return date_range


def get_scheduled_games(date:str) -> list:

    #Returns a week out from the date provided
    r = requests.get(f'https://api-web.nhle.com/v1/schedule/{date}/')

    j = r.json()

    games_list = []

    game_week = j['gameWeek']

    for day in game_week:
        #Only gets the games that happen on the day inputted
        if day['date'] == date :
            for game in day['games']:
                game_id = game['id']
                games_list.append(game_id)
        else:
            continue

    print(games_list)
                
    return games_list


def get_play_by_play(game_id:str) -> bytes:
    '''Takes a gameID and returns the game's play-by-play object'''
    r = requests.get(f'https://api-web.nhle.com/v1/gamecenter/{game_id}/play-by-play')
    
    bytes = r.content

    return bytes


def handler(event=None, context=None):

    today = datetime.today()
    yesterday = today - timedelta(days=1)
    yesterday_str = yesterday.strftime('%Y-%m-%d')

    date_range = generate_date_range(yesterday_str, yesterday_str)

    for date in date_range:
        games = get_scheduled_games(date)
        
        for game_id in games:
            game_obj_bytes = get_play_by_play(game_id)

            client.put_object(
                Body=game_obj_bytes,
                Bucket=os.environ['S3_BUCKET_NAME'],
                Key=f'partition_date={date}/{game_id}.json'
            )

            print(f"Uploaded {game_id}.json to s3.")

if __name__ == "__main__":
    handler()