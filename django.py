# settings.py

# Put the exact URL shown on your Flutter app screen here
# (If using a tunnel like Pinggy or Ngrok, put your public https URL here instead)
SMS_GATEWAY_URL = "http://192.168.100.4:8081/"


# my_auth_app/sms_services.py
import requests
from django.conf import settings

def send_gateway_sms(phone_number, message):
    """
    Sends an SMS payload directly to the running Flutter Android Gateway.
    """
    url = settings.SMS_GATEWAY_URL
    
    # Clean the phone number to ensure it has no spaces or invalid characters
    clean_phone = str(phone_number).strip().replace(" ", "")
    
    # 🌟 Match the exact payload keys expected by your Flutter server
    payload = {
        "phone_number": clean_phone,
        "message": message
    }
    
    try:
        # Set a 5-second timeout so your web server doesn't freeze if the phone goes offline
        response = requests.post(url, json=payload, timeout=5)
        
        if response.status_code == 200:
            print(f"✅ SMS successfully sent to gateway phone for: {clean_phone}")
            return True
        else:
            print(f"❌ Gateway phone rejected request: {response.status_code} - {response.text}")
            return False
            
    except requests.exceptions.Timeout:
        print("⚠️ Timeout: The gateway phone took too long to respond. Is it asleep?")
        return False
    except requests.exceptions.RequestException as e:
        print(f"⚠️ Network Error: Could not connect to the gateway phone: {e}")
        return False




# my_auth_app/signals.py
from django.dispatch import receiver
from django_rest_passwordreset.signals import reset_password_token_created
from .sms_services import send_gateway_sms  # 🌟 Import your helper

@receiver(reset_password_token_created)
def password_reset_token_created(sender, instance, reset_password_token, *args, **kwargs):
    user = reset_password_token.user
    otp_code = reset_password_token.key  # The 6-digit OTP code

    # Check if the user has a registered phone number in your database
    phone_number = getattr(user, 'phone_number', None)
    
    if phone_number:
        # Construct the text message
        sms_body = f"MalaTrade OTP: {otp_code}. Use this code to reset your account password."
        
        # Dispatch immediately to your Android phone!
        send_gateway_sms(phone_number=phone_number, message=sms_body)



# my_auth_app/views.py
from django.http import JsonResponse
from .sms_services import send_gateway_sms

def user_registration_welcome(request):
    # ... after successful user creation logic ...
    
    send_gateway_sms(
        phone_number="+265888123456", 
        message="Welcome to MalaTrade! Your account is now active and ready for secure trading."
    )
    
    return JsonResponse({"status": "user_created"})