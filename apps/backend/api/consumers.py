import json
from urllib.parse import parse_qs
from channels.generic.websocket import AsyncWebsocketConsumer
from channels.db import database_sync_to_async
from rest_framework_simplejwt.tokens import AccessToken
from rest_framework_simplejwt.exceptions import InvalidToken, TokenError
from django.contrib.auth.models import User
from .models import HubMember

class ChatConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        self.hub_id = self.scope['url_route']['kwargs']['hub_id']
        self.room_group_name = f'hub_{self.hub_id}'

        # Authenticate via JWT token in query string
        query_string = self.scope['query_string'].decode()
        query_params = parse_qs(query_string)
        token = query_params.get('token', [None])[0]

        if not token:
            await self.close()
            return

        user = await self.get_user_from_token(token)
        if not user:
            await self.close()
            return

        self.scope['user'] = user

        # Verify the user is a member of the hub
        is_member = await self.is_hub_member(user, self.hub_id)
        if not is_member:
            await self.close()
            return

        # Join room group
        await self.channel_layer.group_add(
            self.room_group_name,
            self.channel_name
        )

        await self.accept()

        # Announce presence (online)
        await self.channel_layer.group_send(
            self.room_group_name,
            {
                'type': 'presence_update',
                'user_id': self.scope['user'].id,
                'user_name': self.scope['user'].username,
                'status': 'online'
            }
        )

    async def disconnect(self, close_code):
        if hasattr(self, 'room_group_name'):
            # Announce presence (offline)
            if 'user' in self.scope and self.scope['user'].is_authenticated:
                await self.channel_layer.group_send(
                    self.room_group_name,
                    {
                        'type': 'presence_update',
                        'user_id': self.scope['user'].id,
                        'user_name': self.scope['user'].username,
                        'status': 'offline'
                    }
                )

            # Leave room group
            await self.channel_layer.group_discard(
                self.room_group_name,
                self.channel_name
            )

    # Receive message from WebSocket (e.g. typing indicators)
    async def receive(self, text_data):
        text_data_json = json.loads(text_data)
        event_type = text_data_json.get('type')
        
        if event_type == 'typing':
            is_typing = text_data_json.get('is_typing', False)
            await self.channel_layer.group_send(
                self.room_group_name,
                {
                    'type': 'typing_update',
                    'user_id': self.scope['user'].id,
                    'user_name': self.scope['user'].username,
                    'is_typing': is_typing
                }
            )

    # Receive chat message from room group
    async def chat_message(self, event):
        message = event['message']

        # Send message to WebSocket
        await self.send(text_data=json.dumps({
            'type': 'chat_message',
            'message': message
        }))

    async def presence_update(self, event):
        await self.send(text_data=json.dumps({
            'type': 'presence_update',
            'user_id': event['user_id'],
            'user_name': event.get('user_name', ''),
            'status': event['status']
        }))

    async def typing_update(self, event):
        await self.send(text_data=json.dumps({
            'type': 'typing_update',
            'user_id': event['user_id'],
            'user_name': event.get('user_name', ''),
            'is_typing': event['is_typing']
        }))

    @database_sync_to_async
    def get_user_from_token(self, token):
        try:
            access_token = AccessToken(token)
            user_id = access_token['user_id']
            return User.objects.get(id=user_id)
        except (InvalidToken, TokenError, User.DoesNotExist):
            return None

    @database_sync_to_async
    def is_hub_member(self, user, hub_id):
        return HubMember.objects.filter(user=user, hub_id=hub_id).exists()
