pipeline {
  // Runs on nacho-3 (Hetzner amd64 VM, Jenkins SSH agent over the tailnet), which has
  // helm and git installed on the host: no build pod or image pull secret needed.
  agent { label 'nacho-3' }

  options {
    disableConcurrentBuilds()
    buildDiscarder(logRotator(numToKeepStr: '20'))
    timeout(time: 20, unit: 'MINUTES')
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
        sh '''#!/bin/bash
          set -euo pipefail

          helm version
          rm -rf dist && mkdir -p dist

          find . -mindepth 2 -maxdepth 5 -name Chart.yaml -not -path "./dist/*" -print | while read -r chart; do
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

    stage('Publish to githubPages repo') {
      steps {
        withCredentials([usernamePassword(
          credentialsId: 'github-pat',
          usernameVariable: 'GH_USER',
          passwordVariable: 'GH_PAT'
        )]) {
          sh '''#!/bin/bash
            set -euo pipefail

            rm -rf gh-pages-repo
            git clone "https://${GH_USER}:${GH_PAT}@github.com/${CHARTS_REPO_OWNER}/${CHARTS_REPO_NAME}.git" gh-pages-repo
            cd gh-pages-repo
            git config user.name  "jenkins"
            git config user.email "jenkins@local"

            mkdir -p charts
            cp -f ../dist/*.tgz charts/

            if [ -f charts/index.yaml ]; then
              helm repo index charts --url "https://${CHARTS_REPO_OWNER}.github.io/charts" --merge charts/index.yaml
            else
              helm repo index charts --url "https://${CHARTS_REPO_OWNER}.github.io/charts"
            fi

            git add charts
            git commit -m "Update Helm charts from ${JOB_NAME}@${BUILD_NUMBER}" || echo "No changes to commit"
            git push origin ${CHARTS_REPO_BRANCH}
          '''
        }
      }
    }
  }

  post {
    always {
      sh 'rm -rf gh-pages-repo dist'
    }
  }
}
