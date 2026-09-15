import json


def lambda_handler(event, context):
    for record in event["Records"]:
        mensagem = record["body"]

        print("Pedido recebido:")
        print(mensagem)

    return {
        "statusCode": 200,
        "body": json.dumps("Pedido processado com sucesso")
    }