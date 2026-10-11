import 'package:flutter/material.dart';
import '../widgets/code_doc_tile.dart';

class DocumentationView extends StatelessWidget {
  const DocumentationView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // 🚀 WHY THIS GATEWAY? OVERVIEW & ADVANTAGES
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.rocket_launch_rounded, color: Color(0xFFFF8C00), size: 24),
                    SizedBox(width: 8),
                    Text(
                      "MalaTrade Open Gateway",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  "Transform any Android phone with an active SIM card into a powerful, cost-effective, automated SMS gateway.",
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13.5, fontWeight: FontWeight.w600, height: 1.4),
                ),
                const SizedBox(height: 12),
                Text(
                  "Built specifically for developers, startups, e-commerce stores, and businesses that need automated SMS capabilities—such as OTP verifications, order updates, booking alerts, and system notifications—without paying exorbitant per-message aggregator tariffs.",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4),
                ),
                const Divider(height: 24),

                const Text(
                  "💡 Why Choose MalaTrade SMS Gateway?",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 8),
                Text(
                  "• Ultra-Low Operational Costs: Eliminate expensive third-party SMS aggregator fees by leveraging local SIM SMS bundles (e.g., TNM or Airtel for Malawi).\n"
                  "• Seamless API Integration: Connect web apps, mobile apps, or backend servers (Python, PHP, Node.js, C#, etc.) in minutes using simple RESTful HTTP endpoints.\n"
                  "• Reliable Auto-Routing: Your backend queues messages, and this mobile gateway fetches and dispatches them automatically in real time.\n"
                  "• Free Trial Included: Get started instantly with 10 free trial SMS credits to test and verify your API integration.",
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12.5, height: 1.5),
                ),
                const Divider(height: 24),

                const Text(
                  "📋 Prerequisites & Operations:",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 8),
                Text(
                  "1. Configure and save your API settings in the Settings tab before starting the engine.\n"
                  "2. Ensure your phone has active SMS bundles (Airtel or TNM for Malawi) or airtime credit.\n"
                  "3. Keep the app open and running to enable real-time background dispatching.\n"
                  "4. Send POST requests to the endpoints below to queue messages automatically from your application.",
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12.5, height: 1.5),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ENDPOINT 1
        const CodeDocTile(
          language: "Endpoint 1: Queue SMS from External App (POST)",
          codeSnippet: r'''
URL: {BASE_URL}/send-sms/
Method: POST
Headers: 
  X-Api-Key: YOUR_CONFIGURED_SECRET_KEY
  Content-Type: application/json

Payload Body:
{
  "phone_number": "+265991234567",
  "message": "Hello! Your code is 4829."
}

Response (201 Created):
{
  "status": "success",
  "message": "SMS queued successfully",
  "sms_id": 101
}''',
        ),

        // ENDPOINT 2
        const CodeDocTile(
          language: "Endpoint 2: Fetch Pending SMS (GET)",
          codeSnippet: r'''
URL: {BASE_URL}/get-pending-sms/
Method: GET
Headers: 
  X-Api-Key: YOUR_CONFIGURED_SECRET_KEY
  Accept: application/json

Response (200 OK):
[
  {
    "id": 101,
    "phone_number": "+265991234567",
    "message": "Hello! Your code is 4829."
  }
]''',
        ),

        // ENDPOINT 3
        const CodeDocTile(
          language: "Endpoint 3: Confirm Dispatch (POST)",
          codeSnippet: r'''
URL: {BASE_URL}/mark-sms-sent/
Method: POST
Headers: 
  X-Api-Key: YOUR_CONFIGURED_SECRET_KEY
  Content-Type: application/json

Payload Body:
{
  "sms_id": 101,
  "status": "SENT"
}''',
        ),

        // PYTHON EXAMPLE
        const CodeDocTile(
          language: "Python / Requests",
          codeSnippet: r'''
import requests

url = "https://malatrade.com/api/send-sms/"
headers = {
    "X-Api-Key": "YOUR_CONFIGURED_SECRET_KEY",
    "Content-Type": "application/json"
}
payload = {
    "phone_number": "+265991234567",
    "message": "Your verification code is 5819."
}

response = requests.post(url, json=payload, headers=headers)
print(response.json())''',
        ),

        // PHP EXAMPLE
        const CodeDocTile(
          language: "PHP (cURL)",
          codeSnippet: r'''
<?php
$ch = curl_init('https://malatrade.com/api/send-sms/');
$payload = json_encode([
    'phone_number' => '+265991234567',
    'message' => 'Your order #1042 has shipped!'
]);

curl_setopt($ch, CURLOPT_POSTFIELDS, $payload);
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    'Content-Type: application/json',
    'X-Api-Key: YOUR_CONFIGURED_SECRET_KEY'
]);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);

$response = curl_exec($ch);
curl_close($ch);
echo $response;
?>''',
        ),

        // NODE.JS EXAMPLE
        const CodeDocTile(
          language: "Node.js (Axios)",
          codeSnippet: r'''
const axios = require('axios');

axios.post('https://malatrade.com/api/send-sms/', {
  phone_number: '+265991234567',
  message: 'Your reservation is confirmed!'
}, {
  headers: {
    'X-Api-Key': 'YOUR_CONFIGURED_SECRET_KEY',
    'Content-Type': 'application/json'
  }
})
.then(res => console.log(res.data))
.catch(err => console.error(err));''',
        ),

        // C# EXAMPLE
        const CodeDocTile(
          language: "C# / HttpClient",
          codeSnippet: r'''
using System.Text;
using System.Text.Json;

var client = new HttpClient();
var request = new HttpRequestMessage(HttpMethod.Post, "https://malatrade.com/api/send-sms/");

request.Headers.Add("X-Api-Key", "YOUR_CONFIGURED_SECRET_KEY");

var payload = new {
    phone_number = "+265991234567",
    message = "Your password reset code is 9102."
};

request.Content = new StringContent(JsonSerializer.Serialize(payload), Encoding.UTF8, "application/json");

var response = await client.SendAsync(request);
var responseText = await response.Content.ReadAsStringAsync();
Console.WriteLine(responseText);''',
        ),
      ],
    );
  }
}