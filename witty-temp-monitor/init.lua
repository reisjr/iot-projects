--init.lua

LED_GREEN = 6 -- GPIO12
LED_BLUE  = 7 -- GPIO13
LED_RED   = 8 -- GPIO15

SAMPLE_TIME = 5 -- in minutes

print("Ready to Set up wifi mode")

wifi.setmode(wifi.STATION)
wifi.sta.config("","")
wifi.sta.connect()

cnt = 0

gpio.mode(LED_GREEN, gpio.OUTPUT)
gpio.mode(LED_BLUE, gpio.OUTPUT)
gpio.mode(LED_RED, gpio.OUTPUT)

gpio.write(LED_BLUE, gpio.HIGH)

tmr.alarm(3, 3000, 1, function() 
    if (wifi.sta.getip() == nil) and (cnt < 10) then 
        print("Trying Connect to Router, Waiting...")
        cnt = cnt + 1 
    else 
        tmr.stop(3)
        if (cnt < 10) then 
            gpio.write(LED_GREEN, gpio.HIGH)
            
            print("Config done, IP is "..wifi.sta.getip())
            
            cnt = nil;
            collectgarbage();
            
            dofile("es_with_callback_deepsleep.lua")
        else 
            gpio.write(LED_BLUE, gpio.LOW)
            gpio.write(LED_RED, gpio.HIGH)
            
            print("Wifi setup time more than 10s, Please verify wifi.sta.config() function. Then re-download the file.")
            
            cnt = nil;
            collectgarbage();

            tmr.alarm(1, 5000, tmr.ALARM_SINGLE, function() node.dsleep(SAMPLE_TIME * 60 * 1000000) end)            
        end
    end
end)




