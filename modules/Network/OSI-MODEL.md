OSI(Open Systems Interconnection) model
7) application layer
6) presentation layer
5) session layer
4) transport layer
3) network layer
2) data link layer
1) physical layer


7) Application layer
    HTTP/HTTPS,dns,smtp,apis
    layer where app sends or receives the data
    ex browser req a webpage or kubernetes service calling another service
    app decides what data needs to be sent over the network

6) Presentation layer
    Layer for format,encrypts or compress the data
    tls/ssl encryption
    data formatting or compression
    ex-> HTTPS works because TLS encryption happens here
    before sending the message lock it so others cant access it

5) Session layer 
    Create and manages communication sessions between systems
    ex -> API session,session tokens,persistent connections
    ex -> your browser keeping a connection open with a server until conversation is finished
    
4) Transport layer
    This layer handles reliable delivery of data
    TCP -> reliable 
    UDP -> fast but unreliable
    also responsible for ports
    if you send 10 packets this layer makes sure all 10 packets are received
    if one packet is missed it will wait for it to resend and resumes data transfer
    
        TCP (Transmission control protocol)
        -> ensures data arrives correctly and in order
            1) Establishes connection (handshake)
            2) Sends packets
            3) Confirms packets arrived (ACK)
            4) Resends missing packets
            5) Ensures correct order
        
         Example -> when you open a website iff packet #4 gets lost TCP will resent packet #4 so page load correctly
        
         TCP can be attacked using SYN flood attacks -> attackers can send many fake connection req and server get exhausted
         protection -> AWS shield , load balancer , rate limiting , WAF

   
        UDP (User datagram protocol)
         -> sends packets without checking if they arrived
             It does NOT:
                  establish connection
                  confirm delivery
                  reorder packets
                  retransmit packets
                  This makes it extremely fast.
                
             UDP is connectionless.
          Example -> video streaming and gaming (If someone misses Packet 3, you don't repeat it.)
          if video call if one fram drops doesnt matter but in tcp video would freeze waiting for missing packets
         UDP risks
              amplification attacks
              spoofing
              DDoS

         Laptop
         ↓
         Home router
         ↓
         ISP
         ↓
         AWS Edge 
         ↓
         Route53
         ↓
         Load Balancer
         ↓
         Kubernetes Ingress
         ↓
         Service
         ↓
         Pod
         ↓
         Database
            
         AWS Edge
         Imagine your server is in Mumbai. But a user is visiting from Germany.
         Without edge:
         Germany → Mumbai 
         Long latency
            
         With edge
         Germany → AWS Edge (Frankfurt)
                     ↓
                   Mumbai
            
         Advantages
         Now:
             static files may be served directly ie Caching (CloudFront)
             security filtering happens early
             latency improves
             TLS Termination
         They mainly run:
             caching
             routing
             security
             acceleration

3) Network Layer
   Layer decides how data travels across networks.
    Main concepts -> ip address,routing,subnets,routers
    ex -> laptop -> router -> internet -> aws server
    system checks where should this package go?->It looks at the address.

2) Data link layer
    Handles comms within same network
    laptop talks to another laptop in the same wi-fi
    main concepts -> MAC address , ethernet , switches    

1) Physical layer
   This layer is actual hardware
    ex -> Ethernet cables , fiber optics , network cards 


    