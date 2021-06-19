def git_repo = 'https://github.com/cakhanif/spring-boot-admin.git'

def git_branch = 'master'
def registry = 'registry.dfx-id.com'
def nexus_base_url = 'https://nexus.dfx-id.com'
//use repo snapshot for development mode
def nexus_deploy_repo = "${nexus_base_url}/repository/maven-snapshots"
def nexus_deps_repo = "${nexus_base_url}/repository/maven"

def health_probe_path = '/'
//docker image prop
def image_builder = 'cakhanif/openjdk8-centos'
def k8s_name = "dfx-dev"

def scale_type = "hpa"
//hpa properties
def max_replica_count = 1
//vpa properties
def vpa_mode = ""

def public_path = "/"
def public_route = ""
def cpu_limit = "300m"
def mem_limit = "384Mi"

def env ="dev"
def purpose = "apps"

//enable pod distruption budget by enable this var
def enable_pdb = false
def countPdb = 1

//enable anti affinity
def anti_affinity = false
//backup src code?
def backup_code = false
def time
//use this when ready to tested or production
def tag
def release 
//notification prop
def teamsWebhookURL = 'https://finstarap.webhook.office.com/webhookb2/a0481707-dbdb-4e34-ad7c-0873ea0f89fe@80ff74d0-d1e7-437b-a030-e7144816b548/JenkinsCI/a8990efad793439aa8bcb0bf4c8dcfb8/0d557952-07e0-426b-9977-093fb8a0adfa'

def appName
def appFullVersion
def gitCommitId

autocancelConsecutiveBuilds()

node ('java-gce-dev') {
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
        appMajorVersion = appFullVersion.substring(0, appFullVersion.indexOf('.'))
        gitCommitId = sh(returnStdout: true, script: 'git rev-parse HEAD').trim()
        echo "appName: '${appName}', appFullVersion:'${appFullVersion}', gitCommitId:'${gitCommitId}'"
        if (backup_code != false || backup_code == true){
            sh """
                echo 'Backup Source Code'
                touch src-${appName}-${appFullVersion}.tar.gz
                tar --exclude src-${appName}-${appFullVersion}.tar.gz --exclude ./target --exclude ./cicd-template -zcvf src-${appName}-${appFullVersion}.tar.gz ./
                curl -u ${nexus_username}:${nexus_password} --upload-file ./src-${appName}-${appFullVersion}.tar.gz ${nexus_git}/${appName}/${appName}-${appFullVersion}-${BUILD_TIMESTAMP}.tar.gz 
                rm src-${appName}-${appFullVersion}.tar.gz
            """
        }
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
    stage ('Archive Jar'){
        sh 'mvn deploy -DskipTests -s ./cicd-template/maven/settings.xml'
    }
    stage ('Build Image'){
        jarFile = sh(returnStdout: true, script: 'find ./target -maxdepth 1 -regextype posix-extended -regex ".+\\.(jar|war)\$" | head -n 1').trim()
        if(jarFile == null || jarFile == ""){
            error 'Can not find the generated jar/war file from "./target" directory'
        }
        jarFile = jarFile.substring('./target/'.length());

        sh """
            set -x
            set -e

            mkdir -p ./target/publish/.s2i
            cp ./target/$jarFile ./target/publish/
            echo 'JAVA_APP_JAR=/deployments/${jarFile}' > ./target/publish/.s2i/environment
        """

        // TODO - make it different stages
        sh """
                set -x
                set -e

                s2i build ./target/publish/ ${image_builder} ${registry}/${git_branch}/${appName}:${appFullVersion}
                docker tag ${registry}/${git_branch}/${appName}:${appFullVersion} ${registry}/${git_branch}/${appName}:latest
                docker push ${registry}/${git_branch}/${appName}:${appFullVersion}
                docker push ${registry}/${git_branch}/${appName}:latest
        """
    }
    //must provide application-dev.yml on repository
    stage("Update ConfigMap"){
        sh """
            gcloud container clusters get-credentials ${k8s_name} --region asia-southeast2
            if [ -f './src/main/resources/application-${env}.yml' ]; then
                kubectl delete cm $appName-v$appMajorVersion -n apps || true
                kubectl create cm $appName-v$appMajorVersion --from-file=application.yml=./src/main/resources/application-${env}.yml -n apps || true
            else
                echo 'Please prepare your ${env} application configuration at "src/main/resources/application-${env}.yml"'
                exit 1
            fi           
        """
    }
    stage('Deploy'){
        sshagent(['ssh-master']) {
            sh """
                ssh -o StrictHostKeyChecking=no 10.143.0.2 ls -al
            """
        }
    }
    stage ('Deploy to Cluster'){
        try {
            //check if branch master need confirm
            if (git_branch == "master"){
                echo "Accept Deploy to Production?"
                confirmProduction(teamsWebhookURL, appName, gitCommitId, appFullVersion)
                input 'Proceed and deploy to Production?'
                currentBuild.result = "CONFIRM"
                
            }
            //check pdb when enabled
            if (enable_pdb == true && countPdb != null){
                echo "Pod Distruption Budget"
                sh """
                    sed -i "s/<APP_NAME>/$appName/g;s/<COUNT_PDB>/$countPdb/g" cicd-template/k8s/pda.yaml

                    kubectl apply -f cicd-template/k8s/pda.yaml
                """
            }
            
            sh """
                sed -i "s/<APP_NAME>/$appName/g;s/<VERSION>/$appMajorVersion/g;s/<BRANCH_NAME>/$git_branch/g;s/<CPU_LIMIT>/$cpu_limit/g;s/<MEM_LIMIT>/$mem_limit/g;s/<GIT_COMMIT_ID>/$gitCommitId/g;s/<APP_VERSION>/$appFullVersion/g" cicd-template/k8s/java/deploy.yaml
                
                sed -i "s/<PURPOSE>/$purpose/g" cicd-template/k8s/patch-nodeselector.yaml
                
                kubectl apply -f cicd-template/k8s/java/deploy.yaml

                kubectl patch deployment $appName-v$appMajorVersion --patch "\$(cat cicd-template/k8s/patch-nodeselector.yaml)" -n apps

                kubectl set image deployment/$appName-v$appMajorVersion $appName-v$appMajorVersion=$registry/$git_branch/$appName:$appFullVersion -n apps --record
            """
            //check anti affinity (prevent same pod replica in same node)
            if (anti_affinity != false || anti_affinity != null || anti_affinity > 0) {
                sh """
                    sed -i "s/<APP_NAME>/$appName/g;s/<VERSION>/$appMajorVersion/g" cicd-template/k8s/patch-podantiaffinity.yaml
                    
                    kubectl patch deployment $appName-v$appMajorVersion --patch "\$(cat cicd-template/k8s/patch-podantiaffinity.yaml)" -n apps
                """
            }
            sh """
                kubectl rollout restart deployment/${appName}-v$appMajorVersion -n apps
                kubectl wait deployment/$appName-v$appMajorVersion --for=condition=available --timeout=1000s -n apps
                kubectl rollout status deployment/${appName}-v$appMajorVersion -n apps
            """            
            //enable Horizontal Pod Autoscaler for Production only
            if (scale_type == "hpa" && max_replica_count != null && max_replica_count > 1){
                echo "Horizontal Pod Autoscaler"
                sh """
                    set -e
                    set -x

                    kubectl autoscale deployment/${appName}-v$appMajorVersion --min 1 --max ${max_replica_count} --cpu-percent=80 -n apps || true
                    kubectl rollout status deployment/${appName}-v$appMajorVersion -n apps
                """
            }
            //enable Vertical Pod Autoscaler for Production only
            if (scale_type == "vpa" && vpa_mode != null){
                echo "Horizontal Pod Autoscaler"
                sh """
                    set -e
                    set -x
                    
                    sed -i "s/<APP_NAME>/$appName/g;s/<VERSION>/$appMajorVersion/g" cicd-template/k8s/vpa.yaml
                    kubectl apply -f cicd-template/k8s/vpa.yaml
                    kubectl rollout status deployment/${appName}-v$appMajorVersion -n apps
                """
            }
            //check expose apps to public
            if (public_route != null && public_route != '' && public_path != '' && public_path != null && public_path != '/'){
                echo "Exposing Endpoint"
                sh """
                    sed -i "s/<APP_NAME>/$appName/g;s/<PUBLIC_ROUTE>/$public_route/g;s/<PUBLIC_PATH>/$public_path/g" cicd-template/k8s/java/ingress.yaml

                    kubectl apply -f cicd-template/k8s/java/ingress.yaml
                """
            }
            currentBuild.result = "SUCCESS"
        }
        catch (e){
            currentBuild.result = "REJECTED"
        }
    }

    stage('Notification'){
        if (currentBuild.result == "SUCCESS") {
            successNotif(teamsWebhookURL, appName, gitCommitId, appFullVersion)
        }
        else if (currentBuild.result == "REJECTED") {
            rejectedNotif(teamsWebhookURL, appName, gitCommitId, appFullVersion)
        }
        else {
            echo "do Nothing"
        }
        echo $currentBuild.result
        //TODO ADD NOTIF PER BRANCH AND STATUS BUILD
    }
}

// catch (e){
//     //sent notification when pipeline failed
//     currentBuild.result = "FAILED"
//     failedNotif(teamsWebhookURL, appName, gitCommitId, appFullVersion)
//     throw e
// }
// }

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

def startedNotif(teamsWebhookURL, appName, gitCommitId, appFullVersion){
    office365ConnectorSend color: '#0018f9', message: "Started Build #${env.BUILD_NUMBER} ${appName} v${appFullVersion} - ${BUILD_TIMESTAMP} | gitCommitID: ${gitCommitId}", status: 'Started', webhookUrl: "$teamsWebhookURL"
}

def confirmProduction(teamsWebhookURL, appName, gitCommitId, appFullVersion){
    office365ConnectorSend color: '#ffff00', message: "Confirm Deploy to Production ? -> #${env.BUILD_NUMBER} ${appName} v${appFullVersion} - ${BUILD_TIMESTAMP} | gitCommitID: ${gitCommitId}", status: 'Confirm', webhookUrl: "$teamsWebhookURL"
}

def successNotif(teamsWebhookURL, appName, gitCommitId, appFullVersion){
    office365ConnectorSend color: '#00fc1d', message: "Success Build #${env.BUILD_NUMBER} ${appName} v${appFullVersion} - ${BUILD_TIMESTAMP} | gitCommitID: ${gitCommitId}", status: 'Success', webhookUrl: "$teamsWebhookURL"
}

def failedNotif(teamsWebhookURL, appName, gitCommitId, appFullVersion){
    office365ConnectorSend color: '#fc0000', message: "Failed Build #${env.BUILD_NUMBER} ${appName} v${appFullVersion} - ${BUILD_TIMESTAMP} | gitCommitID: ${gitCommitId}", status: 'Failed', webhookUrl: "$teamsWebhookURL"
}

def rejectedNotif(teamsWebhookURL, appName, gitCommitId, appFullVersion){
    office365ConnectorSend color: '#fc0000', message: "Rejected Build #${env.BUILD_NUMBER} Production ${appName} v${appFullVersion} - ${BUILD_TIMESTAMP} | gitCommitID: ${gitCommitId}", status: 'Failed', webhookUrl: "$teamsWebhookURL"
}

