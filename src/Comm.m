classdef Comm < handle
    
 
    properties (Constant)
        
        cCONNECTION_SERIAL = 'serial'
        cCONNECTION_TCPIP = 'tcpip'
        cCONNECTION_TCPCLIENT = 'tcpclient'      
        
    end
    
    properties (SetAccess = private)
        
        % tcpclient config
        % --------------------------------
        % {char 1xm} tcp/ip host
        cTcpipHost = '192.168.20.36'
        
        % {uint16 1x1} tcpip port NPort requires a port of 4001 when in
        % "TCP server" mode
        u16TcpipPort = uint16(4001)
        
        
        % serial config
        % --------------------------------
        u16BaudRate = 9600;
        cPort = 'COM1'
        cTerminator = '';
        % {double 1x1} - timeout of MATLAB {serial} - amount of time it will
        % wait for a response before aborting.  
        dTimeout = 2;
        
        cConnection
        
    end 
    
    
    properties (Access = private)
        
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
        
    end
    
    
    
    
end

