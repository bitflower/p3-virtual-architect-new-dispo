# 2026-03-11 Kick-Off Meeting Transcript

KI-generierte Inhalte können fehlerhaft sein

Matthias Max hat die Transkription gestartet

Matthias Max
0 90:09
Matthias Max 0 Minuten 9 Sekunden
So why are we here today? We want to kickstart an initiative that was started by Christian, I think, last year. And it's about getting an Oracle CDC solution in place.
Matthias Max 0 Minuten 27 Sekunden
As you know, we have a CDC mechanism already picked, I think, 1 1/2 years ago for the Postgres databases. And with the recent strategic switch to like...
Matthias Max 0 Minuten 42 Sekunden
Going back in a way to Oracle-based setup for TMS and disposition, there's obviously the need to come up with a CDC solution for these on-premise databases as well.
Matthias Max 0 Minuten 56 Sekunden
The bigger timeline-based context is the new Dispo Go Live, which is currently set around June this year. This is our North Star we work towards, and this Oracle CDC solution is a central building block.
Matthias Max 1 Minute 16 Sekunden
For achieving this, in the end, to be able.
Matthias Max 1 Minute 21 Sekunden
Seven.
Matthias Max 1 Minute 23 Sekunden
In the end, to be able to onboard actual Oracle branches at all.
Matthias Max 1 Minute 30 Sekunden
with a full complete feature scope.
Matthias Max 1 Minute 35 Sekunden
So this is the business context.
Matthias Max 1 Minute 41 Sekunden
There has been a pre-phase where we elaborated on which solutions exist in general. Of course, there's a big market for CDC-based solutions. We have open source, we have commercial products. Four of them were picked in a
MW
Matt Wilkinson
52 Minuten 27 Sekunden52:27
Matt Wilkinson 52 Minuten 27 Sekunden
So I don't know, we might have to handle some, and the reason why I'm saying this is, for example, the character set of UTFA is different to what's on-prem today. A exclamation mark or a piece of data that isn't supported in the current Oracle infrastructure will be
Matt Wilkinson 52 Minuten 47 Sekunden
Received differently, uh, on the other side, and that might be something like, for example, it'll just appear as a question mark.

Matthias Max
52 Minuten 49 Sekunden52:49
Matthias Max 52 Minuten 49 Sekunden
Mm.
Matthias Max 52 Minuten 55 Sekunden
Yeah, so it's...
MW
Matt Wilkinson
52 Minuten 56 Sekunden52:56
Matt Wilkinson 52 Minuten 56 Sekunden
It's like when you put, it's like when you put an emoji in somewhere that doesn't support emojis is what I'll refer to it out for everyone.

Matthias Max
53 Minuten 1 Sekunde53:01
Matthias Max 53 Minuten 1 Sekunde
And.
Matthias Max 53 Minuten 3 Sekunden
Yeah.
MW
Matt Wilkinson
53 Minuten 4 Sekunden53:04
Matt Wilkinson 53 Minuten 4 Sekunden
Yeah, so we just got to watch out for that. That could be it. And for context, the guys are having issues with it now in Poland at the moment, and that's in Oracle with some stuff they're sending.

Matthias Max
53 Minuten 13 Sekunden53:13
Matthias Max 53 Minuten 13 Sekunden
So it's literally just a question of where to parse it correctly in the chain, right?
MW
Matt Wilkinson
53 Minuten 20 Sekunden53:20
Matt Wilkinson 53 Minuten 20 Sekunden
Yeah, yeah, we do. We haven't hit it with Sweden because Sweden got Postgres on UTF 8, so it's quite new and you guys won't see it and you just bought, but the source data of Oracle is not on UTF 8.

Matthias Max
53 Minuten 33 Sekunden53:33
Matthias Max 53 Minuten 33 Sekunden
Mhm, mhm.
Matthias Max 53 Minuten 36 Sekunden
Okay.
MW
Matt Wilkinson
53 Minuten 36 Sekunden53:36
Matt Wilkinson 53 Minuten 36 Sekunden
Just one thing to be aware, but I get just just for knowledge.

Matthias Max
53 Minuten 40 Sekunden53:40
Matthias Max 53 Minuten 40 Sekunden
Yeah, yeah, yeah.
VR
Vervenne, Ron
53 Minuten 40 Sekunden53:40
Vervenne, Ron 53 Minuten 40 Sekunden
We did. Why are we able to do that with the mapping in the history?
MW
Matt Wilkinson
53 Minuten 46 Sekunden53:46
Matt Wilkinson 53 Minuten 46 Sekunden
Yeah, we can do Ron, we can do, yeah, we can do, but that's, but that's with stream, that's with stream. I don't know if you can do with data stream, yeah.
VR
Vervenne, Ron
53 Minuten 46 Sekunden53:46
Vervenne, Ron 53 Minuten 46 Sekunden
But yeah, that thing you can. Yeah, that.
Vervenne, Ron 53 Minuten 51 Sekunden
Yeah, okay.

Matthias Max
53 Minuten 53 Sekunden53:53
Matthias Max 53 Minuten 53 Sekunden
That will be obviously the perfect solution, right, to have it covered by the CDC tool.
VR
Vervenne, Ron
53 Minuten 53 Sekunden53:53
Vervenne, Ron 53 Minuten 53 Sekunden
Yeah, okay, but.
Vervenne, Ron 53 Minuten 58 Sekunden
Mmh.
MW
Matt Wilkinson
53 Minuten 59 Sekunden53:59
Matt Wilkinson 53 Minuten 59 Sekunden
Yeah, yeah.
VR
Vervenne, Ron
54 Minuten54:00
Vervenne, Ron 54 Minuten
I would say that it gives some time already a kind of preference to one solution.
MW
Matt Wilkinson
54 Minuten 7 Sekunden54:07
Matt Wilkinson 54 Minuten 7 Sekunden
Comes with a cost.
VR
Vervenne, Ron
54 Minuten 9 Sekunden54:09
Vervenne, Ron 54 Minuten 9 Sekunden
Yeah, okay, but it's a cost against something that doesn't work. And then I think cost is better than doesn't work.
MW
Matt Wilkinson
54 Minuten 14 Sekunden54:14
Matt Wilkinson 54 Minuten 14 Sekunden
Hang on.
Matt Wilkinson 54 Minuten 16 Sekunden
I agree, I agree.

Matthias Max
54 Minuten 18 Sekunden54:18
Matthias Max 54 Minuten 18 Sekunden
Mm.
Matthias Max 54 Minuten 20 Sekunden
Yeah.
MW
Matt Wilkinson
54 Minuten 21 Sekunden54:21
Matt Wilkinson 54 Minuten 21 Sekunden
Yep. So, you let, there's two, the stream thing we can get, get, tell us when you've got a bucket set up and then we can get that moving quite quickly. Like even I can set that up in stream. It's not a problem.

Matthias Max
54 Minuten 29 Sekunden54:29
Matthias Max 54 Minuten 29 Sekunden
Mmh.
Matthias Max 54 Minuten 32 Sekunden
Okay, nice.
MW
Matt Wilkinson
54 Minuten 33 Sekunden54:33
Matt Wilkinson 54 Minuten 33 Sekunden
Thomas, Thomas can do, Thomas will do it, but I did it with Thomas a long time ago. And then the Oracle stuff, that's a bit different. That's a bit different. I see the data stream CDC.

Matthias Max
54 Minuten 39 Sekunden54:39
Matthias Max 54 Minuten 39 Sekunden
Yeah.
Matthias Max 54 Minuten 45 Sekunden
Mhm.
Matthias Max 54 Minuten 48 Sekunden
Okay.
VR
Vervenne, Ron
54 Minuten 48 Sekunden54:48
Vervenne, Ron 54 Minuten 48 Sekunden
And actually, if you need you not also be aware of the fact that you are now introducing another live database, so that's having more redo files and as well. So it will also be on the same server as the other one, having limited the display there.
MW
Matt Wilkinson
54 Minuten 49 Sekunden54:49
Matt Wilkinson 54 Minuten 49 Sekunden
Yeah.
VR
Vervenne, Ron
55 Minuten 3 Sekunden55:03
Vervenne, Ron 55 Minuten 3 Sekunden
We need to be aware of that.
MW
Matt Wilkinson
55 Minuten 3 Sekunden55:03
Matt Wilkinson 55 Minuten 3 Sekunden
Which?
Matt Wilkinson 55 Minuten 5 Sekunden
Which do you mean, Ron?
VR
Vervenne, Ron
55 Minuten 5 Sekunden55:05
Vervenne, Ron 55 Minuten 5 Sekunden
That.
Vervenne, Ron 55 Minuten 7 Sekunden
If you put the UOT environment is also on the same database server with the same data disc set on it as the original plot ones.
Vervenne, Ron 55 Minuten 18 Sekunden
As far as I'm loyal.
MW
Matt Wilkinson
55 Minuten 20 Sekunden55:20
Matt Wilkinson 55 Minuten 20 Sekunden
Inversible.

Matthias Max
55 Minuten 21 Sekunden55:21
Matthias Max 55 Minuten 21 Sekunden
Oh yeah.
VR

Vervenne, Ron
55 Minuten 21 Sekunden55:21
Vervenne, Ron 55 Minuten 21 Sekunden
Okay.
Vervenne, Ron 55 Minuten 22 Sekunden
Yeah.
MW
Matt Wilkinson
55 Minuten 23 Sekunden55:23
Matt Wilkinson 55 Minuten 23 Sekunden
Yeah, OK. As in the UAT environment that exists today. Yeah, OK. Well, we're not, we haven't decided if we're using that yet. So yeah, I think these people, if this is just for POC, we'll just use the test environment and the test cluster.
VR

Vervenne, Ron
55 Minuten 27 Sekunden55:27
Vervenne, Ron 55 Minuten 27 Sekunden
Yeah, maybe you have a bronze.
Vervenne, Ron 55 Minuten 31 Sekunden
Yeah.
MW
Matt Wilkinson
55 Minuten 38 Sekunden55:38
Matt Wilkinson 55 Minuten 38 Sekunden
In Oracle, because Thomas can, we can, we can simulate the orders via the test environment, that's not a problem.

Matthias Max
55 Minuten 41 Sekunden55:41
Matthias Max 55 Minuten 41 Sekunden
Okay.
MW
Matt Wilkinson
55 Minuten 47 Sekunden55:47
Matt Wilkinson 55 Minuten 47 Sekunden
It's easy to do, do it today with Postgres and other areas, I think.
VR

Vervenne, Ron
55 Minuten 54 Sekunden55:54
Vervenne, Ron 55 Minuten 54 Sekunden
Good.

Matthias Max
55 Minuten 55 Sekunden55:55
Matthias Max 55 Minuten 55 Sekunden
Rights.
MW
Matt Wilkinson
55 Minuten 55 Sekunden55:55
Matt Wilkinson 55 Minuten 55 Sekunden
Yeah.

Matthias Max
55 Minuten 57 Sekunden55:57
Matthias Max 55 Minuten 57 Sekunden
Okay, then we'll be in touch through Martin regarding the meeting.
Matthias Max 56 Minuten 3 Sekunden
And then each party can prepare.
Matthias Max 56 Minuten 6 Sekunden
Their stuff, Max.
VR

Vervenne, Ron
56 Minuten 7 Sekunden56:07
Vervenne, Ron 56 Minuten 7 Sekunden
I.
MW
Matt Wilkinson
56 Minuten 8 Sekunden56:08
Matt Wilkinson 56 Minuten 8 Sekunden
Yep.

Matthias Max
56 Minuten 10 Sekunden56:10
Matthias Max 56 Minuten 10 Sekunden
Okay.
Matthias Max 56 Minuten 12 Sekunden
Good, then if there's no question left, thanks for the time and the exchange.
MW
Matt Wilkinson
56 Minuten 18 Sekunden56:18
Matt Wilkinson 56 Minuten 18 Sekunden
Play.

Matthias Max
56 Minuten 19 Sekunden56:19
Matthias Max 56 Minuten 19 Sekunden
And we speak next week or end of the week. I guess next week.
VR

Vervenne, Ron
56 Minuten 23 Sekunden56:23
Vervenne, Ron 56 Minuten 23 Sekunden
Yeah, that was so good.
MW
Matt Wilkinson
56 Minuten 23 Sekunden56:23
Matt Wilkinson 56 Minuten 23 Sekunden
Next week, next week, end of it.
Matt Wilkinson 56 Minuten 27 Sekunden
Joe, Joe.

Matthias Max
56 Minuten 27 Sekunden56:27
Matthias Max 56 Minuten 27 Sekunden
Alright, bye, bye, bye, bye.
VR

Vervenne, Ron
56 Minuten 27 Sekunden56:27
Vervenne, Ron 56 Minuten 27 Sekunden
Hello.
MW
Matt Wilkinson
56 Minuten 28 Sekunden56:28
Matt Wilkinson 56 Minuten 28 Sekunden
Bye-bye.
YM

Yosif Mihaylov
56 Minuten 29 Sekunden56:29
Yosif Mihaylov 56 Minuten 29 Sekunden
Bye. Bye.
VR

Vervenne, Ron
56 Minuten 29 Sekunden56:29
Vervenne, Ron 56 Minuten 29 Sekunden
Alright.

Matt Wilkinson hat die Transkription gestoppt