def git_repo = 'https://github.com/cakhanif/spring-boot-admin.git'

def git_branch = 'master'
def registry = 'asia.gcr.io/danafix-platform'
def nexus_base_url = 'https://nexus.dfx-id.com'
//use repo snapshot for development mode
def nexus_deploy_repo = "${nexus_base_url}/repository/maven-snapshots"
def nexus_deps_repo = "${nexus_base_url}/repository/maven"

def health_probe_path = '/'
//docker image prop
def image_builder = 'cakhanif/openjdk8-centos'

def env ="dev"

def time
//use this when ready to tested or production
def tag
def release 
//notification prop

def appName
def appFullVersion
def gitCommitId

autocancelConsecutiveBuilds()

node ('java-gce-dev') {
try{
    stage ('Checkout The Code'){
      checkout scm
   }

    stage ('Prepare'){
      withCredentials([[$class: 'UsernamePasswordMultiBinding', 
         credentialsId: 'nexus',
         usernameVariable: 'nexus_username', passwordVariable: 'nexus_password']]) {
               sh """
                  echo 'Downloading cicd templates...'
                  rm -rf cicd-template
                  curl -k --fail -u ${nexus_username}:${nexus_password} -o cicd-template.tar.gz ${nexus_base_url}/repository/dfx-general/cicd-template-${env}.tar.gz
                  mkdir cicd-template && tar -xzvf ./cicd-template.tar.gz -C "\$(pwd)/cicd-template"
                """
                prepareSettingsXml(nexus_deps_repo, nexus_username, nexus_password)
                addDistributionToPom(nexus_deploy_repo)
      }
        appName = getFromPom('name')
        if(appName == null || appName.trim() == ""){
          appName = getFromPom('artifactId')
        }
        if (git_branch == 'master') {
            sh "mvn -s ./cicd-template/maven/settings.xml build-helper:parse-version versions:set -DnewVersion=\\\${parsedVersion.majorVersion}.\\\${parsedVersion.minorVersion}.${BUILD_NUMBER}-RELEASE versions:commit"
        }
        sh "mvn -s ./cicd-template/maven/settings.xml build-helper:parse-version versions:set -DnewVersion=\\\${parsedVersion.majorVersion}.\\\${parsedVersion.minorVersion}.${BUILD_NUMBER}-SNAPSHOT versions:commit"
        appFullVersion = getFromPom('version')
        gitCommitId = sh(returnStdout: true, script: 'git rev-parse HEAD').trim()
        echo "appName: '${appName}', appFullVersion:'${appFullVersion}', gitCommitId:'${gitCommitId}'"
        startedNotif(teamsWebhookURL, appName, gitCommitId)
   }

    //enable when using datamodel
    // stage('Build DataModel') {
    //     sh 'mvn clean package -D skipTests -P data-model -s ./cicd-template/maven/settings.xml'
    // }
    // stage ('Archive DataModel'){
    //     sh 'mvn deploy -DskipTests -P data-model -s ./cicd-template/maven/settings.xml'
    // }
    stage('Build') {
        sh 'mvn clean package -D skipTests -s ./cicd-template/maven/settings.xml'
    }
    //disable on dev and staging env
    //enable when needed for another project
    // stage ('Archive Jar'){
    //     sh 'mvn deploy -DskipTests -s ./cicd-template/maven/settings.xml'
    // }
    
catch (e){
    currentBuild.result = "FAILED"
    failedNotif(teamsWebhookURL, appName, gitCommitId)
    throw e
}
}


def getFromPom(key) {
    sh(returnStdout: true, script: "mvn -s ./cicd-template/maven/settings.xml -q -Dexec.executable=echo -Dexec.args='\${project.${key}}' --non-recursive exec:exec").trim()
}

def addDistributionToPom(nexus_deploy_repo) {
    pom = 'pom.xml'
    distMngtSection = readFile('./cicd-template/maven/pom-distribution-management.xml') 
    distMngtSection = distMngtSection.replaceAll('\\$nexus_deploy_repo', nexus_deploy_repo)

    content = readFile(pom)
    newContent = content.substring(0, content.lastIndexOf('</project>')) + distMngtSection + '</project>'
    writeFile file: pom, text: newContent
}

def prepareSettingsXml(nexus_deps_repo, nexus_username, nexus_password) {
    settingsXML = readFile('./cicd-template/maven/settings.xml') 
    settingsXML = settingsXML.replaceAll('\\$nexus_deps_repo', nexus_deps_repo)
    settingsXML = settingsXML.replaceAll('\\$nexus_username', nexus_username)
    settingsXML = settingsXML.replaceAll('\\$nexus_password', nexus_password)

    writeFile file: './cicd-template/maven/settings.xml', text: settingsXML
}
