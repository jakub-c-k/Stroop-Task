clear device

device_found = 0;
ports = serialportlist("available");

for p = 1:length(ports)
    device = serialport(ports(p),115200,"Timeout",1);
    %In order to identify an XID device, you need to send it "_c1", to
    %which it will respond with "_xid" followed by a protocol value. 0 is
    %"XID", and we will not be covering other protocols.
    device.flush()
    write(device,"_c1","char")
    query_return = read(device,5,"char");
    if length(query_return) > 0 && query_return == "_xid0"
        device_found = 1;
        break
    end
end

if device_found == 0
    disp("No XID device found. Exiting.")
    return
end

disp("Raising all output lines for 1 second.")

%By default the pulse duration is set to 0, which is "indefinite".rgbbrgbb
%You can either set the necessary pulse duration, or simply lower the lines
%manually when desired.

setPulseDuration(device, 50)

%mh followed by two bytes of a bitmask is how you raise/lower output lines.
%Not every XID device supports 16 bits of output, but you need to provide
%both bytes every time.
write(device,sprintf("mh%c%c", 250, 0), "char")


function byte = getByte(val, index)
    byte = bitand(bitshift(val,-8*(index-1)), 255);
end

function setPulseDuration(device, duration)
%mp sets the pulse duration on the XID device. The duration is a four byte
%little-endian integer.

    write(device, sprintf("mp%c%c%c%c", getByte(duration,1),...
        getByte(duration,2), getByte(duration,3),...
        getByte(duration,4)), "char")

end

%% incrementally increasing the pulse value to test how this looks on the recording device. 

for i = 0:255 

    write(device,sprintf("mh%c%c", i, 0), "char")

    pause(0.2)

end