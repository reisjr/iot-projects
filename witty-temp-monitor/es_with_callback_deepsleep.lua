URL_AMAZON = "aws.amazon.com"
URL_ES = ""
MAC = "10:10:10:10"

DHT_PIN = 2  -- GPIO04

MONTHS_TO_NUMBER = {
['Jan'] = '01',
['Feb'] = '02',
['Mar'] = '03',
['May'] = '04',
['Apr'] = '05',
['Jun'] = '06',
['Jul'] = '07',
['Aug'] = '08',
['Sep'] = '09',
['Oct'] = '10',
['Nov'] = '11',
['Dec'] = '12'
}

function read_sensors(date_iso, callback)
    -- Reading temp
    print('Reading sensors...')

    gpio.mode(LED_GREEN, gpio.OUTPUT)
    gpio.mode(LED_RED, gpio.OUTPUT)
    gpio.mode(LED_BLUE, gpio.OUTPUT)
    
    status, temp, humi, temp_dec, humi_dec = dht.read(DHT_PIN)
    
    if status ~= dht.OK then
        print("ERROR reading sensors. Status = "..status)   
        node.dsleep(SAMPLE_TIME * 60 * 1000000)        
    else
        t = temp.."."..temp_dec
        h = humi.."."..humi_dec

        -- Reading light
        local light = 0
        light = adc.read(0)

        if callback ~= nil then
            callback(date_iso, t, h, light)
        end
    end
end

function post_es(date_iso, t, h, light)
    print("post_es dt = "..date_iso.." temp = "..t.." hum = "..h.." light = "..light)
    
    -- Post to ES
    gpio.write(LED_GREEN, gpio.HIGH)
    
    conn=net.createConnection(net.TCP, 0)
    
    conn:on("receive", function(sck, c) 
            print("Receiving return from ES") 
            
            gpio.write(LED_GREEN, gpio.LOW)
            gpio.write(LED_RED, gpio.LOW)
            
            conn:close() 
    end )


      conn:on("connection", function(conn)
          print("Connected to ES...")
    
          gpio.write(LED_GREEN, gpio.HIGH)
          
          if wifi.sta.status() == 5 then
            MAC = wifi.sta.getmac()
          else
            return
          end
                
          data = '{  \"sensor\": \"'..MAC..'\", \"temp\": \"'..t..'\", \"hum\": \"'..h..'\", \"ts\": \"'..date_iso..'\", \"light\": '..light..' }'
    
          id = MAC..date_iso
          id = id:gsub("%T", "")
          id = id:gsub("%:", "")
          id = id:gsub("%-", "")
    
          print('Posting to ES...')
    
          conn:send("POST /sensors/sensor/"..id.." HTTP/1.1\r\n".. 
                 "Host: "..URL_ES.."\r\n"..
                 "Accept: */*\r\n"..
                 "Content-Type: application/json\r\n"..
                 "Content-Length: "..string.len(data).."\r\n"..
                 "Keep-Alive: close".."\r\n"..
                 "\r\n"..data.."\r\n") 
    end )
    
    conn:on("disconnection", function(conn)  
        print("Disconnected from "..URL_ES) 
        gpio.write(LED_GREEN, gpio.LOW)     
        node.dsleep(SAMPLE_TIME * 60 * 1000000)   
    end )
    
    conn:connect(80, URL_ES)
end

function get_time(callback_func)

 date_iso = ''
 gpio.write(LED_BLUE, gpio.HIGH)
 
 conn=net.createConnection(net.TCP, 0)
    conn:on("receive", function(sck, c) 
        get_time_on_receive_callback(sck, c)    
        conn:close()
    end )
    
    conn:on("connection", function(conn)
        get_time_on_connect_callback(conn)
    end)
    
    conn:on("disconnection", function(conn)  
        print("Disconnected from "..URL_AMAZON) 
        callback_func(date_iso)
    end)
    
    conn:connect(80, URL_AMAZON)
end

function get_time_on_receive_callback(sck, c)
    print("Response received. Parsing content...") 
    
    local date = string.match(c, "Date: (.*) GMT")
    
    if(date ~= nil) then
        print("Date found: "..date)
        wk, day, month, year, hour, minute, sec = string.match(date, "(.+), (.+) (.+) (.+) (.+):(.+):(.+)")
        --print(year.."-"..month.."-"..day.." "..hour..":"..minute..":"..sec)
        date_iso = year.."-"..MONTHS_TO_NUMBER[month].."-"..day.."T"..hour..":"..minute..":"..sec
        print("Date ISO "..date_iso)
    end        
end

function get_time_on_connect_callback(conn)
    print("Connected to "..URL_AMAZON)
    print("Trying to retrieve time...")
  
    conn:send("GET /errorpage HTTP/1.1\r\n".. 
         "Host: example.com\r\n"..
         "Accept: */*\r\n"..
         "Content-Type: application/json\r\n"..
         "Keep-Alive: close".."\r\n"..
         "\r\n") 
end

function get_time_callback(date_iso)
    print("This is a callback "..date_iso)
    
    if date_iso ~= '' then           
        gpio.write(LED_BLUE, gpio.LOW)
        read_sensors(date_iso, post_es)
    end
end     

function loop()
    -- Reset LEDs
    gpio.mode(LED_GREEN, gpio.OUTPUT)
    gpio.mode(LED_RED, gpio.OUTPUT)
    gpio.mode(LED_BLUE, gpio.OUTPUT)

    gpio.write(LED_GREEN, gpio.HIGH)
    gpio.write(LED_RED, gpio.LOW)
    gpio.write(LED_BLUE, gpio.HIGH)

    -- Get time
    get_time(get_time_callback)
end

tmr.alarm(1, 1000, tmr.ALARM_SINGLE, function() loop() end)
