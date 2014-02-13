aRby -- Alloy embedded in Ruby
==========

aRby demonstrates the benefits of having a declarative modeling language (backed by an automated solver) embedded in a traditional object-oriented imperative programming language.  This approach aims to bring the two opposing paradigms (imperative and declarative) closer together in a novel and unique way. We show that having the other paradigm available within the same language is beneficial to both the modeling community of Alloy users and the object-oriented community of Ruby programmers.  aRby provides elegant solutions to several well-known, outstanding Alloy problems: (1) mixed execution, (2) specifying partial instances, (3) staged model finding.

## Installation Instructions

aRby requires **Ruby 1.9.3** or later (tested against *1.9.3-p327*, *2.0.0-p353*, and *2.1.0*).  If you are currently using a different Ruby installation, you might want to consider installing the Ruby Version Manager (rvm) to manage your rubies, e.g., 

 ```bash
 rvm get stable
 rvm reload
 rvm install 2.1.0
 rvm use 2.1.0
 ```
 
aRby also requires Java 1.6 or later (to run the Alloy Analyzer), and you must set your `JAVA_HOME` environment variable to point to your **JDK** installation (JRE is not enough), e.g., 

```bash
export JAVA_HOME="/etc/java-6-openjdk" ## or wherever you Java is installed
```
 
To download and install aRby, clone the Git repo, run `bundle install`, then run the unit tests by invoking the 'run_tests.sh' script:

 ```bash
 git clone https://github.com/sdg-mit/arby.git
 cd arby
 bundle install
 ./run_tests.sh
 ```
 
To run a particular test, pass the test file as an argument to the `run_tests.sh` script, e.g.,
 
```bash
 ./run_tests.sh test/unit/arby/models/abz14/sudoku_test.rb
```
  

 
