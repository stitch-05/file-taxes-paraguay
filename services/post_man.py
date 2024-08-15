#!/usr/bin/env python3
import os, smtplib, datetime, sys
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from email.mime.base import MIMEBase
from email import encoders
from typing import List, IO


class EmailMsg(object):
    def __init__(self, send_from: str, send_to: List[str], subject: str,
                 text: str, attachments: List[str]=None):
        self.send_from = send_from
        self.send_to = send_to
        self.subject = subject
        self.text = text
        self.attachments = attachments

    def __repr__(self):
        msg = f"subject: {self.subject};"
        msg += f"attachments: {True if self.attachments else False};"
        if self.attachments:
            msg += f"no_attached: {len(self.attachments)}"
        return msg

    @staticmethod
    def attach_data(data: IO[bytes], file_name: str) -> MIMEBase:
        part = MIMEBase("application", "octet-stream")
        part.set_payload(data.read())
        encoders.encode_base64(part)
        part.add_header(
            "Content-Disposition",
            f"attachment; filename={os.path.basename(file_name)}"
        )
        return part

    def attach_file(self, file_name: str) -> MIMEBase:
        with open(file_name, "rb") as f:
            return self.attach_data(data=f, file_name=file_name)

    def attach_all_attachments(self, message: MIMEMultipart) -> MIMEMultipart:
        for file_ in self.attachments:
            part = self.attach_file(file_name=file_)
            message.attach(part)

        return message

    def build_msg(self) -> str:
        msg = MIMEMultipart()
        msg["From"] = self.send_from
        msg["To"] = ", ".join(self.send_to)
        msg["Subject"] = self.subject
        msg.attach(MIMEText(self.text, "plain"))

        if self.attachments:
            msg = self.attach_all_attachments(message=msg)

        return msg.as_string()


class SMTPPostMan(object):
    def __init__(self, smtp_host: str, smtp_port: int, addr: str, pwd: str):
        self.smtp_host = smtp_host
        self.smtp_port = smtp_port
        self.addr = addr
        self.pwd = pwd

    def _send(self, send_to: List[str], message: EmailMsg) -> None:
        if not self.pwd:
            server = smtplib.SMTP(self.smtp_host, self.smtp_port)
        else:
            server = smtplib.SMTP_SSL(self.smtp_host, self.smtp_port)
        try:
            if self.pwd:
                server.login(self.addr, self.pwd)
            server.sendmail(self.addr, send_to, message.build_msg())

            print(f"{str(datetime.datetime.now()).split('.')[0]}\t{message}")
            print(f'Email sent.\t{self.addr} --> {send_to}')

        finally:
            server.quit()

    def send_email(self, send_to: List[str], subject: str=None, text: str=None,
                   attachments: List[str]=None):
        if not send_to:
            return

        msg = EmailMsg(
            send_from=self.addr,
            send_to=send_to,
            subject=subject if subject else "[no-subject]",
            text=text if text else "[no-text]",
            attachments=attachments
        )
        self._send(send_to=send_to, message=msg)


def main():
    try:
        subject = sys.argv[1]
        message = sys.argv[2]
    except IndexError:
        print("ERROR: Wrong arguments! Need <subject> <message>")
        sys.exit(1)

    mailer = SMTPPostMan(
        smtp_host=os.environ.get("SMTP_HOST"),
        smtp_port=int(os.environ.get("SMTP_PORT")),
        addr=os.environ.get("SMTP_ADDR"),
        pwd=os.environ.get("SMTP_PWD")
    )

    mailer.send_email(
        send_to=[i.strip()
                 for i in os.environ.get("SMTP_RECV").split(";")],
        subject=subject,
        text=message,
    )


if __name__ == '__main__':
    main()

# EOF