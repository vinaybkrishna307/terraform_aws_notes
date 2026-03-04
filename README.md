# cost effective
1)  Always tag resources 
2)  Logs without retention = surprise bill

Burstable instances family ex db.t3.medium
lower guaranteed baseline, and allow temporary bursts?
A burstable instance(t3.medium 2cpu) has a guaranteed baseline CPU performance(20% each) and earns CPU credits when 
running below baseline(if 5% usage ir 20+20-5=35% credits stored). It can temporarily exceed the
baseline by consuming those credits(35%). 
If credits are exhausted(if cpu is at 70% but baseline + credits != 70% ), the instance is throttled back to its baseline performance (in our case 40%).
