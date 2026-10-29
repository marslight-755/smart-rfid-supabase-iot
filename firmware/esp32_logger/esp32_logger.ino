#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <time.h>

const char* WIFI_SSID="YOUR_WIFI"; const char* WIFI_PASSWORD="YOUR_PASSWORD";
const char* ENDPOINT="https://YOUR_PROJECT_REF.supabase.co/functions/v1/ingest-telemetry";
const char* DEVICE_ID="ESP32-001"; const char* DEVICE_KEY="REPLACE_WITH_RANDOM_DEVICE_SECRET";
unsigned long sequenceNo=0; String bootId="";
void setup(){Serial.begin(115200);WiFi.begin(WIFI_SSID,WIFI_PASSWORD);while(WiFi.status()!=WL_CONNECTED)delay(500);configTime(0,0,"pool.ntp.org","time.nist.gov");bootId=String((uint32_t)esp_random(),HEX);}
String isoNow(){time_t t=time(nullptr);struct tm* u=gmtime(&t);char b[30];strftime(b,sizeof(b),"%Y-%m-%dT%H:%M:%SZ",u);return String(b);}
void loop(){if(WiFi.status()==WL_CONNECTED){WiFiClientSecure client;client.setCACert(nullptr); // Replace with Supabase CA certificate for production TLS verification.
HTTPClient http;if(http.begin(client,ENDPOINT)){http.addHeader("Content-Type","application/json");http.addHeader("X-Device-Id",DEVICE_ID);http.addHeader("X-Device-Key",DEVICE_KEY);float temperature=25.0f+(float)(esp_random()%1000)/100.0f;float ph=7.0f+(float)(esp_random()%100)/100.0f;float voltage=3.30f;String body="{\"boot_id\":\""+bootId+"\",\"sequence\":"+String(sequenceNo++)+",\"measured_at\":\""+isoNow()+"\",\"temperature_c\":"+String(temperature,2)+",\"ph\":"+String(ph,2)+",\"voltage_v\":"+String(voltage,3)+",\"status\":\"RUNNING\"}";int code=http.POST(body);Serial.printf("Telemetry upload: %d\n",code);http.end();}}delay(10000);}
