resource "aws_iam_role" "ec2" {
  name = "${var.project_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "ec2_sqs" {
  name = "${var.project_name}-ec2-sqs-policy"
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "sqs:SendMessage"
        ]

        Resource = aws_sqs_queue.pedidos.arn
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2.name
}

resource "aws_instance" "api" {
  ami           = "ami-0faa784aaee9d062c"
  instance_type = "t3.micro"

  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.ec2.id]
  associate_public_ip_address = true

  key_name = "capacita-irede"

  iam_instance_profile = aws_iam_instance_profile.ec2.name

  user_data = <<-EOF
    #!/bin/bash

    dnf update -y
    dnf install -y python3.13 python3.13-pip

    mkdir -p /opt/capacita-irede/api

    cat > /opt/capacita-irede/api/app.py <<'PYTHON'
    from flask import Flask, jsonify, request
    import boto3
    import json
    import os

    app = Flask(__name__)

    sqs = boto3.client(
        "sqs",
        region_name=os.getenv("AWS_REGION", "sa-east-1")
    )

    QUEUE_URL = os.getenv("SQS_QUEUE_URL")

    @app.route("/produtos", methods=["GET"])
    def listar_produtos():
        produtos = [
            {"id": 1, "nome": "Notebook", "preco": 2500.00},
            {"id": 2, "nome": "Mouse", "preco": 80.00},
            {"id": 3, "nome": "Teclado", "preco": 150.00}
        ]

        return jsonify(produtos)

    @app.route("/pedidos", methods=["POST"])
    def criar_pedido():
        pedido = request.get_json()

        if not pedido:
            return jsonify({
                "erro": "Dados do pedido não informados"
            }), 400

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
    PYTHON

    python3.13 -m pip install Flask boto3

    cat > /etc/systemd/system/capacita-api.service <<'SERVICE'
    [Unit]
    Description=API Capacita iRede
    After=network.target

    [Service]
    Type=simple
    WorkingDirectory=/opt/capacita-irede/api
    Environment="AWS_REGION=sa-east-1"
    Environment="SQS_QUEUE_URL=${aws_sqs_queue.pedidos.url}"
    ExecStart=/usr/bin/python3.13 /opt/capacita-irede/api/app.py
    Restart=always

    [Install]
    WantedBy=multi-user.target
    SERVICE

    systemctl daemon-reload
    systemctl enable capacita-api
    systemctl start capacita-api
  EOF

  tags = {
    Name = "${var.project_name}-ec2"
  }
}