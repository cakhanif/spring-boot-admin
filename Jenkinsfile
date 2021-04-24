node {
  stage('Checkout'){
    git url: "https://github.com/cakhanif/spring-boot-admin", branch: "master", credentiaslId: "gituser"
  }
  stage('Build'){
    sh "mvn clean package -DskipTests"
  }
  stage('Deploy'){
    sh """
      scp ./target/spring-boot-admin-k8s-1.0.0.jar cakhanif@10.140.0.3:~/cakhanif
      
      ssh cakhanif@10.140.0.3 java -jar /home/cakhanif/spring-boot-admin-k8s-1.0.0.jar -Dport=8080
    """
  }
}
