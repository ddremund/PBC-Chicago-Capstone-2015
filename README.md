# Partner Bootcamp Contribution Instructions

## Overview

**Welcome to DataStax Partner Bootcamp!**

*This README file contains the instructions of what you will need to supply for
evaluation.* For each of the labs, use strategic and functional
 comments and supply summary documentation comments in your code so
 that we may appropriately assess your efforts.
 
 **Please read each portion carefully.**

## Documentation Requirements

1. All documents should be written as .txt, .md or html only.
2. Include both strategic and functional documentation of your code for review.
3. Include a summary of what either you personally performed or what did with
   your team. Therefore, you should be taking notes during the entire duration
   of the labs.

### GitHub Workflow

**Steps:**

1. Fork the PBC repository on GitHub under your GitHub handle. *Note:* Every person will have
their own fork. When you work in pairs, you simply submit the same `writeup.txt`
file with your forked copy. The only time this will be different is for Bare OS
Install when you will submit 1 document on your own and 1 with your group.
2. The repository will remain Private, when you fork it will still remain private.
You will have write access, meaning you can push and pull, but please only push
to YOUR fork.

### Schedule

### Directory Structure

```
.
├── Bare-OS-Install
│       └── writeup.txt
├── Capstone
│       └── writeup.txt
├── Cluster-Confusion
│       └── writeup.txt
├── Disfigured-Data
│       ├── JMX
│       ├── schema.txt
│       └── writeup.txt
└── README.md
```

### Cluster Confusion

Submit one `writeup.txt` document per group including your documentation
and summary. Make sure to add your cluster number in your writeup as well.

| Group Number| Workstation | OpsCenter |
| ---------- |:-------------:| :----------: |
| Group 1: Name - [GitHub Username](Link to forked repo), Name - [GitHub Username](Link to forked repo) | xx.xx.xxx.xxx |  http://xx.xx.xx.xx:8888
| Group 2: Name - [GitHub Username](Link to forked repo), Name - [GitHub Username](Link to forked repo) | xx.xx.xxx.xxx |  http://xx.xx.xx.xx:8888
| Group 3: Name - [GitHub Username](Link to forked repo), Name - [GitHub Username](Link to forked repo) | xx.xx.xxx.xxx |  http://xx.xx.xx.xx:8888
| Group 4: Name - [GitHub Username](Link to forked repo), Name - [GitHub Username](Link to forked repo) | xx.xx.xxx.xxx |  http://xx.xx.xx.xx:8888
| Group 5:Name - [GitHub Username](Link to forked repo), Name - [GitHub Username](Link to forked repo) | xx.xx.xxx.xxx |  http://xx.xx.xx.xx:8888
| Group 6: Name - [GitHub Username](Link to forked repo), Name - [GitHub Username](Link to forked repo) | xx.xx.xxx.xxx |  http://xx.xx.xx.xx:8888
| Group 8: Demo Cluster |   User Workstation: xx.xx.xx.xxx  |  http://xx.xx.xx.xxx:8888

### Bare OS Install

| Group Number| Workstation | OpsCenter |
| ---------- |:-------------:| :----------: |
| Group 1: Name - [GitHub Username](Link to forked repo), Name - [GitHub Username](Link to forked repo) | xx.xx.xxx.xxx |  http://xx.xx.xx.xx:8888
| Group 2: Name - [GitHub Username](Link to forked repo), Name - [GitHub Username](Link to forked repo) | xx.xx.xxx.xxx |  http://xx.xx.xx.xx:8888
| Group 3: Name - [GitHub Username](Link to forked repo), Name - [GitHub Username](Link to forked repo) | xx.xx.xxx.xxx |  http://xx.xx.xx.xx:8888
| Group 4: Name - [GitHub Username](Link to forked repo), Name - [GitHub Username](Link to forked repo) | xx.xx.xxx.xxx |  http://xx.xx.xx.xx:8888
| Group 5:Name - [GitHub Username](Link to forked repo), Name - [GitHub Username](Link to forked repo) | xx.xx.xxx.xxx |  http://xx.xx.xx.xx:8888
| Group 6: Name - [GitHub Username](Link to forked repo), Name - [GitHub Username](Link to forked repo) | xx.xx.xxx.xxx |  http://xx.xx.xx.xx:8888
| Group 8: Demo Cluster |   User Workstation: xx.xx.xx.xxx  |  http://xx.xx.xx.xxx:8888

Submit one `writeup.txt` document per person and one document per group.
There should be four documents at the end.

### Disfigured Data

| Group Number| Workstation | OpsCenter |
| ---------- |:-------------:| :----------: |
| Group 1: Name - [GitHub Username](Link to forked repo), Name - [GitHub Username](Link to forked repo) | xx.xx.xxx.xxx |  http://xx.xx.xx.xx:8888
| Group 2: Name - [GitHub Username](Link to forked repo), Name - [GitHub Username](Link to forked repo) | xx.xx.xxx.xxx |  http://xx.xx.xx.xx:8888
| Group 3: Name - [GitHub Username](Link to forked repo), Name - [GitHub Username](Link to forked repo) | xx.xx.xxx.xxx |  http://xx.xx.xx.xx:8888
| Group 4: Name - [GitHub Username](Link to forked repo), Name - [GitHub Username](Link to forked repo) | xx.xx.xxx.xxx |  http://xx.xx.xx.xx:8888
| Group 5:Name - [GitHub Username](Link to forked repo), Name - [GitHub Username](Link to forked repo) | xx.xx.xxx.xxx |  http://xx.xx.xx.xx:8888
| Group 6: Name - [GitHub Username](Link to forked repo), Name - [GitHub Username](Link to forked repo) | xx.xx.xxx.xxx |  http://xx.xx.xx.xx:8888
| Group 8: Demo Cluster |   User Workstation: xx.xx.xx.xxx  |  http://xx.xx.xx.xxx:8888

Submit your jMeter output in `JMX`, DESC KEYSPACES output in `schema`, and a
summary in `writeup.txt`.

### Capstone (Final Project)

Submit your documentation in `writeup.txt`. Your code should be submitted **to
your group's** repository, forked from [this repo](https://github.com/DataStax-Enablement/PBC-Paris-Capstone-2015). Indicate who was in your group in the readme file of your forked repo. 

You may also submit your presentation in the `PBC-Paris-Capstone-2015` repository as well if it is a code-based presentation framework. Otherwise, place it in google drive, in the presentations folder by Saturday.

**Capstone Presentation guidelines:**

Consider that you are presenting to a customer with a retail use case for Black Friday. They need a solution which will be able to hand the impact of heavy traffic for Black Friday. By generating a demo/POC, you have given them the supplemental technical proof of concept, but you will also need to supply the messaging and framing around the implementation. 

Please create a presentation that is no more than 20 minutes in length to describe the most salient points of what you implemented leveraging the DSE stack: Cassandra, Solr and Spark. Present this as you would to a customer. 

*Presentation Time*: 1pm on Nov. 6th. 

*Presentation Length*: 20 minutes/group.

**Topics to cover**: 
* Overall POC: what did the customer have before you did this work and after?
* Describing what you did: do not do a code review -- explain at a high level what you did and why.
* Visualizing what you added: This is up to you, others have done chord charts in D3, do what you like.
* Next steps/Q&A.
* Code is due by Midnight on Nov. 7th.


| Group Link | Group Members |
| ---------- |:-------------:|
| [Group 1](link) | [Name](link), [Name](link), [Name](link), [Name](Link)
| [Group 2](to be added) | names to be added
| [Group 3](to be added) | names to be added
| [Group 4](to be added) | names to be added
| [Group 5](to be added) | names to be added
| [Group 6](to be added) | names to be added
| [Group 7](to be added) | names to be added
=======
