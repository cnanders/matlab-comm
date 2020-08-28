classdef Comm < handle
    
 
    properties (Constant)
        
        cCONNECTION_SERIAL = 'serial'
        cCONNECTION_TCPIP = 'tcpip'
        cCONNECTION_TCPCLIENT = 'tcpclient'      
        
    end
    
    properties (SetAccess = protected)
        
        % {char 1xm}
        cConnection % cCONNECTION_SERIAL | cCONNECTION_TCPCLIENT
        
        % tcpclient config
        % --------------------------------
        % {char 1xm} tcp/ip host
        cTcpipHost = '192.168.20.36'
        
        % {uint16 1x1} tcpip port NPort requires a port of 4001 when in
        % "TCP server" mode
        u16TcpipPort = uint16(4001)
        
        
        % serial config
        % --------------------------------
        u16BaudRate = uint16(9600)
        cPort = 'COM1'
        cTerminator = '';
        
        
        % {double 1x1} - timeout of MATLAB {serial} - amount of time it will
        % wait for a response before aborting.  
        dTimeout = 2;
        
        
        
        % ascii config for ascii messages
        % --------------------------------
        u8TerminatorWrite = uint8([13 10]) % carriage return new line
        u8TerminatorRead = uint8([13 10])
        
    end 
    
    
    properties (Access = protected)
        
        comm
        
        % debug config
        lShowWaitingForBytes = false;
        
        % {logical 1x1} true when waiting for a response. 
        lIsBusy = false
        
    end
    
    methods
        
        function this = Comm(varargin)
            
            this.cConnection = this.cCONNECTION_TCPCLIENT;
            
            for k = 1 : 2: length(varargin)
                this.msg(sprintf('passed in %s', varargin{k}));
                if this.hasProp( varargin{k})
                    this.msg(sprintf('settting %s', varargin{k}));
                    this.(varargin{k}) = varargin{k + 1};
                end
            end
            
        end
        
        function delete(this)
            this.comm = [];
        end
        
        
        function init(this)
            
            switch this.cConnection
                case this.cCONNECTION_SERIAL
                    try
                        this.msg('init() creating serial instance');
                        this.comm = serial(this.cPort);
                        this.comm.BaudRate = this.u16BaudRate;
                        this.comm.Terminator = this.cTerminator;
                        % this.comm.InputBufferSize = this.u16InputBufferSize;
                        % this.comm.OutputBufferSize = this.u16OutputBufferSize;
                    catch ME
                        rethrow(ME)
                    end
              case this.cCONNECTION_TCPCLIENT
                    try
                       this.msg('init() creating tcpclient instance');
                       this.comm = tcpclient(this.cTcpipHost, this.u16TcpipPort);
                    catch ME
                        rethrow(ME)
                    end
            end
            
            this.clearBytesAvailable();
        end
        
        % Reads all available bytes from the input buffer
        function clearBytesAvailable(this)

            this.lIsBusy = true;
            while this.comm.BytesAvailable > 0
                cMsg = sprintf(...
                    'clearBytesAvailable() clearing %1.0f bytes\n', ...
                    this.comm.BytesAvailable ...
                );
                fprintf(cMsg);
                bytes = read(this.comm, this.comm.BytesAvailable);
            end
            this.lIsBusy = false;
        end
        
    end
    
    
    methods (Access = protected)
        
        
        function msg(~, cMsg)
            cTimestamp = datestr(datevec(now), 'yyyymmdd-HHMMSS', 'local');
            fprintf('%s: Comm %s\n', cTimestamp, cMsg);
        end
        
        function l = hasProp(this, c)
            
            l = false;
            if ~isempty(findprop(this, c))
                l = true;
            end
            
        end
        
        % {uint8 m x 1} list of bytes in decimal including terminator
        function write(this, u8Data)
            
            if ~isa(u8Data, 'uint8')
                error('u8Data must be uint8 data type');
            end
            
            % Echo each byte in HEX
            % fprintf('Comm.write() hex bytes:');
            % dec2hex(double(u8Data))
            
            switch this.cConnection
                case {this.cCONNECTION_SERIAL, this.cCONNECTION_TCPIP}
                    fwrite(this.comm, u8Data);
                case this.cCONNECTION_TCPCLIENT
                    write(this.comm, u8Data);
            end
        end
        
        % Writes an ASCII command to the communication object (serial,
        % tcpip, or tcpclient
        % Create the binary command packet as follows:
        % Convert the char command into a list of uint8 (decimal), 
        % concat with the terminator
        
        function writeAscii(this, cCmd)
            % this.msg(sprintf('write %s', cCmd))
            u8Cmd = [uint8(cCmd) this.u8TerminatorWrite];
            this.write(u8Cmd);
        end
        
        
        % Blocks execution until the serial has provided BytesAvailable
        % @param {int 1x1} the number of bytes to wait for
        % @return {logical 1x1} returns true if found the expected number
        % of bytes before the timeout
        function lSuccess = waitForBytesAvailable(this, dBytesExpected)
            
                        
            if this.lShowWaitingForBytes
                cMsg = sprintf(...
                    'waitForBytesAvailable(%1.0f)', ...
                    dBytesExpected ...
                );
                this.msg(cMsg);
            end
                  
            tic
            while this.comm.BytesAvailable < dBytesExpected
                
                if this.lShowWaitingForBytes
                    cMsg = sprintf(...
                        'waitForBytesAvailable() ... %1.0f of %1.0f expected bytes are currently available', ...
                        this.comm.BytesAvailable, ...
                        dBytesExpected ...
                    );
                    this.msg(cMsg);
                end
                
                if (toc > this.dTimeout)
                    cMsg = sprintf(...
                        'waitForByetesAvailable() timeout (> %1.1f sec) did not reach expected BytesAvailable (%1.0f)', ...
                        this.dTimeout, ...
                        dBytesExpected ...
                    );
                    lSuccess = false;
                    this.msg(cMsg);
                    return
                end
            end
            
            lSuccess = true;
            
        end
        
        
        % Read until the terminator is reached and convert to ASCII if
        % necessary (tcpip and tcpclient transmit and receive binary data).
        % @return {char 1xm} the ASCII result
        
        function [c, lSuccess] = readAscii(this)
            
            [u8Result, lSuccess] = this.readToTerminator();
            
            if lSuccess == false
                c = char(u8Result);
                return
            end
            
            % remove terminator
            u8Result = u8Result(1 : end - length(this.u8TerminatorRead));
            % convert to ASCII (char)
            c = char(u8Result);
                
        end
        
        
        % Returns {uint8 1xm} list of uint8, one for each byte of the
        % response, including the terminator bytes
        % Returns {logical 1x1} true if bytes are read before timeout,
        % false otherwise
        function [u8Result, lSuccess] = readToTerminator(this)
            
            lTerminatorReached = false;
            u8Result = [];
            idTic = tic;
            while(~lTerminatorReached )
                if (this.comm.BytesAvailable > 0)
                    
                    cMsg = sprintf(...
                        'readToTerminator reading %u bytesAvailable', ...
                        this.comm.BytesAvailable ...
                    );
                    this.msg(cMsg);
                    % Append available bytes to previously read bytes
                    
                    % {uint8 1xm} 
                    u8Val = read(this.comm, this.comm.BytesAvailable);
                    % {uint8 1x?}
                    u8Result = [u8Result u8Val];
                    
                    % search new data for terminator
                    % convert to ASCII and use strfind, since
                    % terminator can be multiple characters
                    
                    if contains(char(u8Val), char(this.u8TerminatorRead))
                        lTerminatorReached = true;
                    end
                end
                
                if (toc(idTic) > this.comm.Timeout)
                    
                    lSuccess = false;
                    
                    cMsg = sprintf(...
                        'Error.  readToTerminator took too long (> %1.1f sec) to reach terminator', ...
                        this.dTimeout ...
                    );
                    this.msg(cMsg);
                    return
                    
                end
            end
            
            lSuccess = true;
            
            
        end
        
    end
    
    
    
    
end

