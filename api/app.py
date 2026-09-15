from flask import Flask, jsonify, request
import boto3
import json
import os

app = Flask(__name__)

sqs = boto3.client("sqs", region_name=os.getenv("AWS_REGION", "sa-east-1"))

QUEUE_URL = os.getenv("SQS_QUEUE_URL")


@app.route("/produtos", methods=["GET"])
def listar_produtos():
    produtos = [
        {
            "id": 1,
            "nome": "Notebook",
            "preco": 2500.00
        },
        {
            "id": 2,
            "nome": "Mouse",
            "preco": 80.00
        },
        {
            "id": 3,
            "nome": "Teclado",
            "preco": 150.00
        }
    ]

    return jsonify(produtos)


@app.route("/pedidos", methods=["POST"])
def criar_pedido():
    pedido = request.get_json()

    if not pedido:
        return jsonify({"erro": "Dados do pedido não informados"}), 400

    sqs.send_message(
        QueueUrl=QUEUE_URL,
        MessageBody=json.dumps(pedido)
    )

    return jsonify({
        "mensagem": "Pedido enviado para processamento",
        "pedido": pedido
    }), 202


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80)