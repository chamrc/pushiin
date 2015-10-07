# HackCMU 2015
Printing from iOS and Android devices to the Andrew Printing queue has never been made easier.

##Inspiration
We face the hassle of printing out our assignments/lecture notes every day though the CMU queue every day, which can get annoying since it requires a laptop with no mobile options. Pushiin allows you to print documents anywhere through a click on your iOS or mobile device in real-time, with even less latency than printing from a laptop.

##What it does
An Android and IOS app that allows you to send PDF files to it, and sends it to the CMU printing queue of a custom Andrew ID.

##How I built it
iOS and Android app sends POST request to a Node-based server, which then forwards the pdf to the appropriate printing queue.

##Challenges I ran into
This was our first foray into iOS and Android development, so we took quite alot of time figuring out the vagaries of the language.

##Built with:
node.js, ios, android, cups, shell
