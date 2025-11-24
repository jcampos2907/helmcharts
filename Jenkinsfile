pipeline {
  agent {
    kubernetes {
      defaultContainer "jnlp"
      yaml """
apiVersion: v1
kind: Pod
spec:
  imagePullSecrets:
    - name: regcred
  containers:
  - name: helm
    image: jicamposr/helm:v3.16.4        # your custom helm image
    command: ["sh", "-c", "sleep infinity"]
    tty: true

  - name: git
    image: jicamposr/git:2.52.0            # small image with git + sh
    command: ["sh", "-c", "sleep infinity"]
    tty: true
"""
    }
  }

  environment {
    CHARTS_REPO_OWNER  = "jcampos2907"
    CHARTS_REPO_NAME   = "jcampos2907.github.io"
    CHARTS_REPO_BRANCH = "main"
  }

  stages {
    stage('Checkout') {
      steps {
        retry(3) {
          checkout scm
        }
      }
    }

    stage('Package Helm charts') {
      steps {
        container('helm') {
          sh '''
            set -euo pipefail

            helm version
            mkdir -p dist

            find . -mindepth 2 -maxdepth 5 -name Chart.yaml -print | while read chart; do
              chart_dir=$(dirname "$chart")
              echo "==> Packaging chart at $chart_dir"
              helm lint "$chart_dir"
              helm package "$chart_dir" --destination dist
            done

            echo "Packaged charts:"
            ls -l dist
          '''
        }
      }
    }

    stage('Publish to githubPages repo') {
      steps {
        withCredentials([usernamePassword(
          credentialsId: 'github-pat',
          usernameVariable: 'GH_USER',
          passwordVariable: 'GH_PAT'
        )]) {

          // 1) Git-only: clone gh-pages repo + copy tgz
          container('git') {
            sh '''
              set -euo pipefail

              git config --global user.name  "jenkins"
              git config --global user.email "jenkins@local"

              CHARTS_REPO_URL="https://${GH_USER}:${GH_PAT}@github.com/${CHARTS_REPO_OWNER}/${CHARTS_REPO_NAME}.git"

              rm -rf gh-pages-repo
              git clone "$CHARTS_REPO_URL" gh-pages-repo

              mkdir -p gh-pages-repo/charts
              cp -f dist/*.tgz gh-pages-repo/charts/
            '''
          }

          // 2) Helm-only: (re)generate index.yaml inside repo
          container('helm') {
            sh '''
              set -euo pipefail
              cd gh-pages-repo

              if [ -f charts/index.yaml ]; then
                helm repo index charts \
                  --url "https://${CHARTS_REPO_OWNER}.github.io/charts" \
                  --merge charts/index.yaml
              else
                helm repo index charts \
                  --url "https://${CHARTS_REPO_OWNER}.github.io/charts"
              fi
            '''
          }

          // 3) Git-only: commit + push changes
          container('git') {
            sh '''
              set -euo pipefail
              cd gh-pages-repo

              git add charts
              git commit -m "Update Helm charts from ${JOB_NAME}@${BUILD_NUMBER}" || echo "No changes to commit"
              git push origin ${CHARTS_REPO_BRANCH}
            '''
          }
        }
      }
    }
  }
}
